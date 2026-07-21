# CI Release Automation + Local Lifecycle Test Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Automatically cut a GitHub Release (and sync About/topics) when a version bump lands on `master` after tests pass, and provide a local command that waits for CI to go green then runs a real-world uninstall/install lifecycle test.

**Architecture:** Extend the existing `.github/workflows/test.yml` with two push-only jobs (`release`, `sync-metadata`) that `needs: [tier1, tier2]`. Extract the plugin lifecycle into a reusable shell library (`scripts/lib/lifecycle.sh`) sourced by both the CI Tier 2 job and a new local `scripts/verify-release.sh` (which adds a `gh run watch` green-gate on top).

**Tech Stack:** Bash, GitHub Actions, `gh` CLI, `claude plugin` CLI, `python3` (JSON parsing, already used by existing scripts).

## Global Constraints

- Plugin manifest path (verbatim): `plugins/improve-prompt/.claude-plugin/plugin.json`
- Marketplace manifest path (verbatim): `.claude-plugin/marketplace.json`
- Plugin name: `improve-prompt`; marketplace name: `improve-prompt-marketplace`; install spec: `improve-prompt@improve-prompt-marketplace`
- Expected skill dir: `skills/start/`; expected derived command: `improve-prompt:start`; stale dir that must be absent: `skills/improve-prompt/`
- Current version: `1.1.0`; existing tags: `v1.0.1`, `v1.0.2`, `v1.1.0` (no `v1.0.0` tag)
- All lifecycle CLI calls MUST run against a throwaway `CLAUDE_CONFIG_DIR` (`mktemp -d`, trap-cleaned) — never the real `~/.claude`.
- Shell scripts use `set -uo pipefail` and the existing pass/fail color-helper convention (`ok`/`bad`).
- `gh release create` needs `permissions: contents: write`; repo-metadata edits are best-effort (`continue-on-error: true`).
- Remote: `github.com/ricardorqr/improve-prompt-plugin`; `gh` is installed and authed as `ricardorqr`.
- Commit message trailer (verbatim, every commit): `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`

---

### Task 1: Extract the reusable lifecycle library

Pull the six-step real-world lifecycle into a sourced library so both CI and the local runner share one implementation. This task delivers the library plus a thin CI-facing entrypoint that reproduces today's Tier 2 coverage using the new flow.

**Files:**
- Create: `scripts/lib/lifecycle.sh`
- Rewrite: `scripts/smoke-lifecycle.sh` (becomes a thin caller of the library)
- Reference (do not change): `scripts/test.sh` (pattern source for `ok`/`bad`/colors)

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces (sourced by Task 2 and Task 3):
  - Env contract: caller exports `ROOT` (repo root) before sourcing.
  - `lifecycle_prev_tag <new_version>` → echoes the newest tag strictly older than `v<new_version>`, or empty string if none. Return 0 always.
  - `run_lifecycle` → runs the full six-step flow against a fresh throwaway config dir; echoes progress via `ok`/`bad`; returns 0 if all steps pass, 1 otherwise. Reads `ROOT`. Self-contained (creates and traps its own `mktemp -d`).

- [ ] **Step 1: Write the failing test (a temporary harness that sources the lib and asserts the functions exist)**

Create `scripts/lib/.lifecycle-selftest.sh` (temporary, deleted in Step 6):

```bash
#!/usr/bin/env bash
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT/scripts/lib/lifecycle.sh"

fail=0
type ok         >/dev/null 2>&1 || { echo "MISSING: ok"; fail=1; }
type bad        >/dev/null 2>&1 || { echo "MISSING: bad"; fail=1; }
type run_lifecycle     >/dev/null 2>&1 || { echo "MISSING: run_lifecycle"; fail=1; }
type lifecycle_prev_tag >/dev/null 2>&1 || { echo "MISSING: lifecycle_prev_tag"; fail=1; }

# prev tag of 1.1.0 must be v1.0.2 given the repo's tag set
got="$(lifecycle_prev_tag 1.1.0)"
[ "$got" = "v1.0.2" ] || { echo "prev_tag(1.1.0)=$got expected v1.0.2"; fail=1; }
# prev tag of 1.0.1 must be empty (v1.0.0 tag does not exist)
got="$(lifecycle_prev_tag 1.0.1)"
[ -z "$got" ] || { echo "prev_tag(1.0.1)=$got expected empty"; fail=1; }

[ "$fail" -eq 0 ] && echo "SELFTEST OK" || echo "SELFTEST FAIL"
exit "$fail"
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash scripts/lib/.lifecycle-selftest.sh`
Expected: FAIL — `scripts/lib/lifecycle.sh` does not exist yet, so `source` errors with "No such file or directory" (non-zero exit).

- [ ] **Step 3: Write the library**

Create `scripts/lib/lifecycle.sh`:

```bash
#!/usr/bin/env bash
#
# Reusable improve-prompt lifecycle helpers.
#
# Contract: the caller MUST export ROOT (repo root) before sourcing this file.
# Nothing here touches the real ~/.claude — run_lifecycle creates its own
# throwaway CLAUDE_CONFIG_DIR and trap-cleans it.
#
# Provides:
#   ok / bad                 — pass/fail reporters (increment $pass/$fail)
#   lifecycle_prev_tag VER   — newest git tag strictly older than vVER (or "")
#   run_lifecycle            — full six-step real-world flow; 0=pass 1=fail

# --- identity (pinned; the point of the test is to assert these) -------------
LC_PLUGIN="improve-prompt"
LC_MARKET="improve-prompt-marketplace"
LC_SPEC="$LC_PLUGIN@$LC_MARKET"
LC_SKILL="start"
LC_COMMAND="improve-prompt:start"

pass=0 fail=0
green="$(printf '\033[32m')"; red="$(printf '\033[31m')"; dim="$(printf '\033[2m')"; rst="$(printf '\033[0m')"
ok()  { pass=$((pass+1)); printf "  %sPASS%s %s\n" "$green" "$rst" "$1"; }
bad() { fail=$((fail+1)); printf "  %sFAIL%s %s\n" "$red" "$rst" "$1"; [ -n "${2:-}" ] && printf "       %s%s%s\n" "$dim" "$2" "$rst"; }

# Newest tag strictly older than vVER, by version sort. Empty if none.
lifecycle_prev_tag() { # <new_version>
  local newv="$1"
  git -C "$ROOT" tag -l 'v*' \
    | sort -V \
    | awk -v cur="v$newv" '{ if ($0 == cur) exit; print }' \
    | tail -1
}

# HEAD's version from the plugin manifest.
lifecycle_head_version() {
  python3 -c 'import json;print(json.load(open("'"$ROOT"'/plugins/improve-prompt/.claude-plugin/plugin.json"))["version"])'
}

# Record the on-disk install dir(s) for the plugin under a config dir.
_lc_installed_paths() { # <cfg>
  find "$1" -type d -path "*/$LC_PLUGIN/*" -prune -print 2>/dev/null | head -20
}

# Assert every recorded version dir is "removed" after uninstall. On CLI 2.1.x
# `claude plugin uninstall` deregisters the plugin and marks its cache dir
# .orphaned_at for deferred GC rather than deleting it (and no purge command
# exists), so "removed" means absent OR carrying an .orphaned_at tombstone —
# not physically gone.
_lc_assert_tombstoned() { # <label> <newline-separated paths>
  local label="$1" paths="$2" live="" path
  while IFS= read -r path; do
    [ -z "$path" ] && continue
    if [ -e "$path" ] && [ ! -f "$path/.orphaned_at" ]; then
      live="$path"; break
    fi
  done <<< "$paths"
  if [ -z "$live" ]; then
    ok "$label removed or tombstoned (.orphaned_at) after uninstall"
  else
    bad "$label still live on disk (no .orphaned_at)" "$live"
  fi
}

run_lifecycle() {
  local cfg newv oldtag details old_dir newdir
  cfg="$(mktemp -d)"
  # shellcheck disable=SC2317
  _lc_cleanup() { rm -rf "$cfg"; }
  trap _lc_cleanup RETURN

  local pcli
  pcli() { CLAUDE_CONFIG_DIR="$cfg" claude plugin "$@"; }

  newv="$(lifecycle_head_version)"
  oldtag="$(lifecycle_prev_tag "$newv")"

  printf "%sthrowaway config dir: %s%s\n" "$dim" "$cfg" "$rst"
  printf "%snew version: %s   old tag: %s%s\n\n" "$dim" "$newv" "${oldtag:-<none>}" "$rst"

  # === Phase OLD: install previous release, then uninstall and verify gone ===
  printf "Old version\n"
  local old_ref="$ROOT"
  if [ -n "$oldtag" ]; then
    # Materialize the old tag's tree in a temp checkout so the marketplace
    # source reflects the previous release, not HEAD.
    old_dir="$(mktemp -d)"
    if git -C "$ROOT" archive "$oldtag" | tar -x -C "$old_dir"; then
      old_ref="$old_dir"
      ok "materialized old release $oldtag"
    else
      bad "could not materialize $oldtag; using HEAD for old phase"
    fi
  else
    printf "  %s(no earlier tag than v%s — old phase uses HEAD)%s\n" "$dim" "$newv" "$rst"
  fi

  if pcli marketplace add "$old_ref" >/dev/null 2>&1 && pcli install "$LC_SPEC" >/dev/null 2>&1; then
    ok "installed old version from ${oldtag:-HEAD}"
  else
    bad "old install failed" "$(pcli install "$LC_SPEC" 2>&1 | tail -3)"
  fi
  local old_paths
  old_paths="$(_lc_installed_paths "$cfg")"

  pcli uninstall "$LC_PLUGIN" >/dev/null 2>&1
  if pcli list 2>&1 | grep -qi "$LC_PLUGIN"; then
    bad "old version still listed after uninstall"
  else
    ok "old version deregistered (gone from \`plugin list\`)"
  fi
  _lc_assert_tombstoned "old-version files" "$old_paths"
  [ -n "${old_dir:-}" ] && rm -rf "$old_dir"

  # === Phase NEW: install HEAD, verify features, uninstall, verify gone =====
  printf "\nNew version\n"
  pcli marketplace add "$ROOT" >/dev/null 2>&1
  pcli marketplace update "$LC_MARKET" >/dev/null 2>&1
  if pcli install "$LC_SPEC" >/dev/null 2>&1; then
    ok "installed new version from HEAD"
  else
    bad "new install failed" "$(pcli install "$LC_SPEC" 2>&1 | tail -3)"
  fi

  details="$(pcli details "$LC_PLUGIN" 2>&1)"
  printf '%s' "$details" | grep -q "$newv" \
    && ok "installed version is $newv" \
    || bad "version $newv not in details" "$(printf '%s' "$details" | head -3)"

  # Feature checks are scoped to the LIVE installed version dir, not the whole
  # config dir — tombstoned (.orphaned_at) dirs left by the old phase must not
  # leak into the new-version assertions.
  newdir="$cfg/plugins/cache/$LC_MARKET/$LC_PLUGIN/$newv"
  [ -d "$newdir/skills/$LC_SKILL" ] \
    && ok "installed copy has skills/$LC_SKILL/" \
    || bad "installed copy missing skills/$LC_SKILL/" "$newdir"

  if [ -d "$newdir/skills/improve-prompt" ]; then
    bad "stale skills/improve-prompt/ present" "$newdir/skills/improve-prompt"
  else
    ok "no stale skills/improve-prompt/ in installed copy"
  fi

  # Derived command = <plugin name>:<skill dir name>, from the installed copy.
  local pname sdir sname derived
  pname="$(python3 -c 'import json;print(json.load(open("'"$ROOT"'/plugins/improve-prompt/.claude-plugin/plugin.json"))["name"])')"
  sdir="$(find "$newdir/skills" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | head -1)"
  sname="$(basename "${sdir:-$LC_SKILL}")"
  derived="$pname:$sname"
  [ "$derived" = "$LC_COMMAND" ] \
    && ok "derived command is /$LC_COMMAND" \
    || bad "derived command is /$derived, expected /$LC_COMMAND"

  pcli uninstall "$LC_PLUGIN" >/dev/null 2>&1
  if pcli list 2>&1 | grep -qi "$LC_PLUGIN"; then
    bad "new version still listed after uninstall"
  else
    ok "new version deregistered (gone from \`plugin list\`)"
  fi
  _lc_assert_tombstoned "new-version files" "$newdir"

  printf "\n%d passed, %d failed\n" "$pass" "$fail"
  [ "$fail" -eq 0 ]
}
```

- [ ] **Step 4: Run the self-test to verify it passes**

Run: `bash scripts/lib/.lifecycle-selftest.sh`
Expected: prints `SELFTEST OK`, exit 0. (Only exercises `lifecycle_prev_tag` + function presence — `run_lifecycle` is exercised in Step 5.)

- [ ] **Step 5: Rewrite `scripts/smoke-lifecycle.sh` as a thin caller and run it**

Replace the entire contents of `scripts/smoke-lifecycle.sh` with:

```bash
#!/usr/bin/env bash
#
# Tier 2 — real-world uninstall/install lifecycle smoke test.
#
# Runs against a THROWAWAY config dir so it never touches your real ~/.claude.
# Delegates to scripts/lib/lifecycle.sh (shared with scripts/verify-release.sh).
# Tests the committed working tree — commit local changes first to cover them.
#
# Exit 0 = pass, 1 = fail.

set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ROOT
# shellcheck source=lib/lifecycle.sh
source "$ROOT/scripts/lib/lifecycle.sh"

printf "improve-prompt · Tier 2 lifecycle smoke test\n"
run_lifecycle
```

Run: `./scripts/smoke-lifecycle.sh`
Expected: PASS section-by-section, ending `N passed, 0 failed`, exit 0. (Requires the `claude` CLI on PATH and network for the git-based marketplace.)

- [ ] **Step 6: Delete the temporary self-test and commit**

```bash
rm scripts/lib/.lifecycle-selftest.sh
git add scripts/lib/lifecycle.sh scripts/smoke-lifecycle.sh
git commit -m "Extract reusable six-step lifecycle library

Move the install/uninstall verification into scripts/lib/lifecycle.sh and
reshape smoke-lifecycle.sh into a thin caller. The new flow: install+uninstall
the previous tag (verify files gone), then install HEAD, verify features,
uninstall, verify gone.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Local wait-for-green runner

Add the local-only script that blocks on CI going green for the current commit, then runs the shared lifecycle.

**Files:**
- Create: `scripts/verify-release.sh`

**Interfaces:**
- Consumes: `scripts/lib/lifecycle.sh` (`run_lifecycle`, reads `ROOT`) from Task 1.
- Produces: a user-facing command; nothing later depends on it.

- [ ] **Step 1: Write the failing test (syntax + wiring check harness)**

Create `scripts/.verify-release-selftest.sh` (temporary, deleted in Step 5):

```bash
#!/usr/bin/env bash
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0
[ -f "$ROOT/scripts/verify-release.sh" ] || { echo "MISSING script"; fail=1; }
bash -n "$ROOT/scripts/verify-release.sh" || { echo "SYNTAX ERROR"; fail=1; }
grep -q 'gh run' "$ROOT/scripts/verify-release.sh" || { echo "no gh run gate"; fail=1; }
grep -q 'run_lifecycle' "$ROOT/scripts/verify-release.sh" || { echo "does not call run_lifecycle"; fail=1; }
[ "$fail" -eq 0 ] && echo "SELFTEST OK" || echo "SELFTEST FAIL"
exit "$fail"
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash scripts/.verify-release-selftest.sh`
Expected: FAIL — prints `MISSING script` (and `SELFTEST FAIL`), exit 1.

- [ ] **Step 3: Write `scripts/verify-release.sh`**

```bash
#!/usr/bin/env bash
#
# Local, wait-for-green release verification.
#
# 1. Waits for the CI run of the current HEAD commit on the remote to conclude.
# 2. Aborts unless that run succeeded.
# 3. Runs the shared six-step lifecycle (scripts/lib/lifecycle.sh) against a
#    throwaway config dir — the real ~/.claude is never touched.
#
# Requires: gh (authed), claude CLI, network. Run AFTER pushing.
# Exit 0 = CI green AND lifecycle passed.

set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ROOT
# shellcheck source=lib/lifecycle.sh
source "$ROOT/scripts/lib/lifecycle.sh"

dim="$(printf '\033[2m')"; red="$(printf '\033[31m')"; rst="$(printf '\033[0m')"
die() { printf "%sverify-release: %s%s\n" "$red" "$1" "$rst" >&2; exit 1; }

command -v gh >/dev/null 2>&1 || die "gh CLI not found on PATH"

sha="$(git -C "$ROOT" rev-parse HEAD)"
printf "verify-release · waiting for CI on %s%s%s\n" "$dim" "${sha:0:12}" "$rst"

# Find the most recent run for this commit. Retry briefly — the run may not be
# registered the instant after a push.
run_id=""
for _ in 1 2 3 4 5 6; do
  run_id="$(gh run list --commit "$sha" --limit 1 --json databaseId \
              --jq '.[0].databaseId' 2>/dev/null)"
  [ -n "$run_id" ] && break
  printf "  %sno run yet for this commit; retrying in 10s…%s\n" "$dim" "$rst"
  sleep 10
done
[ -n "$run_id" ] || die "no CI run found for $sha (did you push this commit?)"

printf "  watching run %s…\n" "$run_id"
# --exit-status makes gh return non-zero if the run concluded in failure.
if ! gh run watch "$run_id" --exit-status >/dev/null 2>&1; then
  die "CI run $run_id did not succeed — not running lifecycle"
fi
printf "  CI is green ✓\n\n"

printf "improve-prompt · lifecycle (post-green)\n"
run_lifecycle
```

- [ ] **Step 4: Run the self-test to verify it passes**

Run: `bash scripts/.verify-release-selftest.sh`
Expected: prints `SELFTEST OK`, exit 0.

- [ ] **Step 5: Make executable, delete the self-test, and commit**

```bash
chmod +x scripts/verify-release.sh
rm scripts/.verify-release-selftest.sh
git add scripts/verify-release.sh
git commit -m "Add local wait-for-green release verifier

scripts/verify-release.sh blocks on the current commit's CI run via
\`gh run watch --exit-status\`, then runs the shared lifecycle only if green.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Repo-metadata config + release/sync CI jobs

Add the committed metadata file and extend `test.yml` with the two push-only jobs. This is one task because the `sync-metadata` job is meaningless without its config file, and both jobs share the same gating and belong to the same reviewer decision ("does CI now cut releases correctly?").

**Files:**
- Create: `.github/repo-metadata.json`
- Modify: `.github/workflows/test.yml` (append two jobs after `tier2`)
- Modify: `README.md` (document the release flow + `verify-release.sh`; add the metadata-token caveat)

**Interfaces:**
- Consumes: `.github/repo-metadata.json` (read by the `sync-metadata` job).
- Produces: nothing consumed by later tasks (final task).

- [ ] **Step 1: Write the failing test (workflow + metadata validation harness)**

Create `scripts/.ci-jobs-selftest.sh` (temporary, deleted in Step 7):

```bash
#!/usr/bin/env bash
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WF="$ROOT/.github/workflows/test.yml"
META="$ROOT/.github/repo-metadata.json"
fail=0

[ -f "$META" ] || { echo "MISSING repo-metadata.json"; fail=1; }
if [ -f "$META" ]; then
  python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d["description"] and d["homepage"] and isinstance(d["topics"],list) and d["topics"]' "$META" \
    || { echo "repo-metadata.json missing description/homepage/topics"; fail=1; }
fi

# Workflow must define both new jobs, gated on push+master, needing both tiers.
python3 - "$WF" <<'PY' || fail=1
import sys, re
wf = open(sys.argv[1]).read()
problems = []
for job in ("release:", "sync-metadata:"):
    if job not in wf:
        problems.append(f"job {job} missing")
if "needs: [tier1, tier2]" not in wf:
    problems.append("release/sync must 'needs: [tier1, tier2]'")
if "refs/heads/master" not in wf:
    problems.append("missing master ref guard")
if "contents: write" not in wf:
    problems.append("missing contents: write permission")
if "continue-on-error: true" not in wf:
    problems.append("sync-metadata must be continue-on-error")
if "gh release create" not in wf:
    problems.append("no 'gh release create' step")
if problems:
    print("WORKFLOW PROBLEMS:", "; ".join(problems)); sys.exit(1)
PY

[ "$fail" -eq 0 ] && echo "SELFTEST OK" || echo "SELFTEST FAIL"
exit "$fail"
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash scripts/.ci-jobs-selftest.sh`
Expected: FAIL — `MISSING repo-metadata.json` and `WORKFLOW PROBLEMS: job release: missing; ...`, exit 1.

- [ ] **Step 3: Create `.github/repo-metadata.json`**

Values mirror the current live sidebar (About blurb + the 8 topics from the screenshot).

```json
{
  "description": "A Claude Code plugin that rewrites draft prompts into clearer, more effective ones — two improved variants plus a recommendation.",
  "homepage": "https://github.com/ricardorqr/improve-prompt-plugin",
  "topics": [
    "plugin",
    "productivity",
    "ai",
    "prompt",
    "claude",
    "prompt-engineering",
    "claude-code",
    "claude-code-plugin"
  ]
}
```

- [ ] **Step 4: Append the two jobs to `.github/workflows/test.yml`**

Add after the end of the `tier2:` job (keep everything above unchanged):

```yaml

  release:
    name: Cut GitHub release on version bump
    runs-on: ubuntu-latest
    needs: [tier1, tier2]
    if: github.event_name == 'push' && github.ref == 'refs/heads/master'
    permissions:
      contents: write
    steps:
      - uses: actions/checkout@v5
        with:
          fetch-depth: 0

      - name: Determine version and whether a release is needed
        id: v
        run: |
          version="$(python3 -c 'import json;print(json.load(open("plugins/improve-prompt/.claude-plugin/plugin.json"))["version"])')"
          echo "version=$version" >> "$GITHUB_OUTPUT"
          if git rev-parse "v$version" >/dev/null 2>&1 \
             || gh release view "v$version" >/dev/null 2>&1; then
            echo "needed=false" >> "$GITHUB_OUTPUT"
            echo "v$version already released — nothing to do."
          else
            echo "needed=true" >> "$GITHUB_OUTPUT"
          fi
        env:
          GH_TOKEN: ${{ github.token }}

      - name: Extract changelog notes for this version
        if: steps.v.outputs.needed == 'true'
        run: |
          version="${{ steps.v.outputs.version }}"
          # Print the body between "## [$version]" and the next "## [" header.
          awk -v ver="$version" '
            $0 ~ "^## \\[" ver "\\]" {grab=1; next}
            grab && /^## \[/ {exit}
            grab {print}
          ' CHANGELOG.md > release-notes.md
          if [ ! -s release-notes.md ]; then
            echo "Release v$version" > release-notes.md
          fi
          echo "----- release notes -----"; cat release-notes.md

      - name: Create release
        if: steps.v.outputs.needed == 'true'
        run: |
          version="${{ steps.v.outputs.version }}"
          gh release create "v$version" \
            --title "v$version" \
            --notes-file release-notes.md \
            --latest
        env:
          GH_TOKEN: ${{ github.token }}

  sync-metadata:
    name: Sync About + topics (best-effort)
    runs-on: ubuntu-latest
    needs: [tier1, tier2]
    if: github.event_name == 'push' && github.ref == 'refs/heads/master'
    continue-on-error: true
    permissions:
      contents: write
    steps:
      - uses: actions/checkout@v5

      - name: Apply repo metadata
        run: |
          desc="$(python3 -c 'import json;print(json.load(open(".github/repo-metadata.json"))["description"])')"
          home="$(python3 -c 'import json;print(json.load(open(".github/repo-metadata.json"))["homepage"])')"
          topics="$(python3 -c 'import json;print(",".join(json.load(open(".github/repo-metadata.json"))["topics"]))')"
          echo "Setting description + homepage…"
          gh repo edit "$GITHUB_REPOSITORY" --description "$desc" --homepage "$home" \
            || echo "WARN: could not set description/homepage (token may lack admin)"
          echo "Setting topics: $topics"
          IFS=',' read -ra arr <<< "$topics"
          args=(); for t in "${arr[@]}"; do args+=(-f "names[]=$t"); done
          gh api -X PUT "repos/$GITHUB_REPOSITORY/topics" \
            -H "Accept: application/vnd.github+json" "${args[@]}" \
            || echo "WARN: could not set topics (token may lack admin)"
        env:
          GH_TOKEN: ${{ github.token }}
```

- [ ] **Step 5: Update `README.md` (Testing/Release section)**

Add a subsection documenting the flow. Insert near the existing testing docs:

```markdown
### Releasing

Releases are automated. Bump the version in
`plugins/improve-prompt/.claude-plugin/plugin.json` (and keep `CITATION.cff`
+ the top `CHANGELOG.md` entry in sync — Tier 1 enforces this), then push to
`master`. Once **Tier 1** and **Tier 2** pass, CI:

- **`release`** — if the version has no matching tag yet, creates `vX.Y.Z` and a
  GitHub Release whose notes are the `## [X.Y.Z]` changelog section. Idempotent:
  an already-released version is a no-op.
- **`sync-metadata`** — best-effort sync of the repo About description, homepage,
  and topics from `.github/repo-metadata.json`.

> **Note:** `sync-metadata` runs with `continue-on-error` because the default
> `GITHUB_TOKEN` may lack permission to edit repo settings (org policy /
> `administration` scope). If it warns, apply the metadata once locally:
> `gh repo edit ricardorqr/improve-prompt-plugin --description "…" --homepage "…"`.

After pushing, verify locally that CI is green **and** the install/uninstall
lifecycle is clean in one command:

```bash
./scripts/verify-release.sh
```

It waits for the pushed commit's CI run to conclude, then (only if green) runs
the six-step real-world lifecycle against a throwaway config dir.
```

- [ ] **Step 6: Run the self-test to verify it passes**

Run: `bash scripts/.ci-jobs-selftest.sh`
Expected: prints `SELFTEST OK`, exit 0.

- [ ] **Step 7: Validate workflow YAML, delete the self-test, and commit**

```bash
python3 -c 'import sys,yaml; yaml.safe_load(open(".github/workflows/test.yml")); print("YAML OK")' 2>/dev/null \
  || python3 -c 'import json; print("(pyyaml absent — skipping YAML lint)")'
rm scripts/.ci-jobs-selftest.sh
git add .github/repo-metadata.json .github/workflows/test.yml README.md
git commit -m "Automate GitHub release + sidebar metadata on version bump

Extend test.yml with push-only release + sync-metadata jobs gated on
[tier1, tier2]. release cuts vX.Y.Z + a GitHub Release from the changelog when
the version has no tag yet; sync-metadata best-effort syncs About/topics from
.github/repo-metadata.json. Document the flow and verify-release.sh in README.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review

**Spec coverage:**
- Release on version bump, gated on tests → Task 3 `release` job (`needs: [tier1, tier2]`, tag-existence no-op). ✓
- CHANGELOG-sourced notes → Task 3 Step 4 `awk` extractor. ✓
- About + topics sync, best-effort, token caveat → Task 3 `sync-metadata` (`continue-on-error`) + README note. ✓
- Wait-for-green local runner → Task 2 `verify-release.sh` (`gh run watch --exit-status`). ✓
- Six-step real-world lifecycle (old install→uninstall→verify gone→new install→verify features→uninstall→verify gone) → Task 1 `run_lifecycle`. ✓
- "Old version = previous git tag; degrade if none" → Task 1 `lifecycle_prev_tag` + HEAD fallback (self-tested: `1.1.0`→`v1.0.2`, `1.0.1`→empty). ✓
- Throwaway `CLAUDE_CONFIG_DIR`, never touch `~/.claude` → Task 1 `mktemp -d` + `trap … RETURN`. ✓
- Supersede `smoke-lifecycle.sh` → Task 1 Step 5 rewrites it as a thin caller. ✓
- Tier 1 + pre-push hook unchanged → not modified by any task. ✓

**Placeholder scan:** No TBD/TODO/"handle edge cases"/"similar to Task N". All code shown in full. The only intentional literal `TODO`-shaped strings are none. ✓

**Type consistency:** `run_lifecycle`, `lifecycle_prev_tag`, `ok`, `bad`, `ROOT` are defined in Task 1 and consumed by the same names in Tasks 2. Identity constants (`improve-prompt`, `improve-prompt:start`, `skills/start/`) match the Global Constraints and spec. Job names (`release`, `sync-metadata`), `needs: [tier1, tier2]`, and `contents: write` are consistent between Task 3's code and its self-test. ✓
