# CI release automation + local wait-for-green lifecycle test

**Date:** 2026-07-20
**Status:** Approved (design)

## Problem

Two gaps in the current automation:

1. **Releases are cut by hand.** CI (`.github/workflows/test.yml`) runs Tier 1
   static validation and Tier 2 lifecycle, but nothing maintains the GitHub
   sidebar. The three existing releases were created manually, and the About
   description / topics can drift from the repo.
2. **No CI-gated local verification.** `scripts/smoke-lifecycle.sh` does an
   install → uninstall → reinstall cycle, but there is no way to (a) wait for CI
   to go green before trusting a push and (b) exercise the real-world
   "uninstall the old version, install the new one, confirm both leave no
   residue" sequence.

## Goals

- On a version bump landing on `master`, automatically cut a matching git tag +
  GitHub Release (updating the sidebar's **Releases / Latest**), only after both
  test tiers pass.
- Keep the **About** description and **topic tags** in sync from a committed
  config file (best-effort).
- Provide one local command that blocks until the pushed commit's CI run is
  green, then runs the full real-world uninstall/install lifecycle against a
  throwaway config dir.

## Non-goals

- Publishing an npm / GitHub Package (the plugin is not distributed that way).
- Automating Languages / License / Contributors / Cite-this-repository — GitHub
  derives all of these automatically (`CITATION.cff` version is already pinned
  by Tier 1).

## Current state (grounding)

- `gh` 2.96.0 installed and authed as `ricardorqr`; remote is
  `github.com/ricardorqr/improve-prompt-plugin`.
- Tags present: `v1.0.1`, `v1.0.2`, `v1.1.0` (no `v1.0.0` tag despite the
  CHANGELOG entry). Current `plugin.json` version is `1.1.0`.
- `CHANGELOG.md` uses `## [X.Y.Z] - DATE` sections with link refs at the bottom
  — easy to slice release notes from.
- Tier 1 (`scripts/test.sh`) pins version agreement across `plugin.json`,
  `CITATION.cff`, and the top CHANGELOG entry, plus skill layout / command
  derivation / marketplace source.
- Tier 2 (`scripts/smoke-lifecycle.sh`) runs install → uninstall → reinstall in
  a throwaway `CLAUDE_CONFIG_DIR`.

## Design

### Part 1 — Release automation inside `test.yml`

Extend the existing workflow rather than add a `workflow_run`-triggered one (that
trigger is flaky). New jobs run only on `push` to `master` and declare
`needs: [tier1, tier2]`, so nothing releases unless both tiers pass.

**Job `release`**
- `if: github.event_name == 'push' && github.ref == 'refs/heads/master'`
- `needs: [tier1, tier2]`
- `permissions: { contents: write }`
- Steps:
  1. Read `version` from `plugins/improve-prompt/.claude-plugin/plugin.json`.
  2. If tag `v$VERSION` already exists (`git rev-parse` / `gh release view`) →
     no-op and exit 0 (idempotent; the existing `v1.1.0` is never re-cut).
  3. Otherwise extract the `## [$VERSION]` section body from `CHANGELOG.md` as
     the notes, then `gh release create "v$VERSION" --title "v$VERSION"
     --notes-file <notes> --latest`. `gh` creates the tag as part of this.

**Job `sync-metadata`**
- Same `if:` gating, `needs: [tier1, tier2]`, `permissions: { contents: write }`.
- `continue-on-error: true` — a token/permission failure here must not fail the
  release.
- Reads a new committed file `.github/repo-metadata.json`:
  ```json
  {
    "description": "<About blurb>",
    "homepage": "https://github.com/ricardorqr/improve-prompt-plugin",
    "topics": ["plugin", "productivity", "ai", "prompt", "claude",
               "prompt-engineering", "claude-code", "claude-code-plugin"]
  }
  ```
- Applies it via `gh repo edit --description --homepage` and
  `gh api PUT /repos/{owner}/{repo}/topics` (or `gh repo edit --add-topic`).
- **Caveat:** editing description/topics with the default `GITHUB_TOKEN` may
  require `permissions: administration: write` and can be blocked by org policy.
  Because the job is `continue-on-error`, releases still succeed; the documented
  fallback is running the same `gh repo edit` once locally.

### Part 2 — `scripts/verify-release.sh` (local, wait-for-green)

Uses the local authed `gh`. Steps:

1. **Wait for green.** Resolve the latest CI run for the current `HEAD` commit on
   `master` (`gh run list`/`gh run watch`). Block until it concludes; abort
   (non-zero) if the conclusion is not `success`.
2. **Run the lifecycle core** (see below). On success, print a summary.

### Lifecycle core (shared by `verify-release.sh` and CI Tier 2)

Refactor so the six-step flow lives in one place, callable both locally (after
the green wait) and from CI (without the wait). Everything runs against a
`mktemp -d` `CLAUDE_CONFIG_DIR`, trap-cleaned on exit — the real `~/.claude` is
never touched.

Version resolution:
- **NEW** = version in `plugin.json` at HEAD.
- **OLD** = the most recent git tag strictly before HEAD's version (e.g. `v1.0.2`
  when HEAD is `v1.1.0`). If none exists, degrade to using the current version
  for the "old" phase and log that the old/new distinction was skipped.

Steps:
1. Add marketplace pinned to the **OLD** tag → install → **record installed file
   paths** (the on-disk plugin dir under the throwaway config).
2. **Uninstall old** → assert every recorded path is gone AND the plugin is
   absent from `plugin list` and `plugin details`.
3. Add marketplace at **HEAD (new)** → install.
4. **Verify features of the new version** on the installed copy:
   - skill dir `skills/start/` exists,
   - derived command is `improve-prompt:start`,
   - installed version matches `plugin.json`,
   - no stale `skills/improve-prompt/` directory.
5. **Uninstall new** → assert all recorded new paths gone + deregistered.

This **supersedes `smoke-lifecycle.sh`**: that script is reshaped into the
lifecycle core (the old install→uninstall→reinstall ordering is dropped in favor
of the six-step real-world flow). CI's Tier 2 job calls the core; the pre-push
hook is unchanged (still Tier 1 only).

## Testing

- Tier 1 (`scripts/test.sh`) unchanged; still gates locally + in CI.
- Lifecycle core exercised by CI Tier 2 on every push/PR and by
  `verify-release.sh` locally after CI is green.
- Release job idempotency verified by the fact that `v1.1.0` already exists →
  first run must no-op, not error.

## Risks / open items

- `GITHUB_TOKEN` may lack permission to edit repo description/topics →
  mitigated by `continue-on-error` + documented local fallback.
- `gh release create` needs `contents: write` (always grantable).
- The "old version" install pulls a previous tag's marketplace; if a very old
  tag is structurally incompatible with the current CLI, the old-phase install
  could fail — acceptable, and surfaced as a clear failure.
