# Variant-Locked Commands Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `/improve-prompt:coding`, `/improve-prompt:writing`, and `/improve-prompt:analysis` — three new commands that each hard-lock a single variant of the existing `improve-prompt:start` rewrite process, with no inference and no fallback to General.

**Architecture:** Three new self-contained `SKILL.md` files under `plugins/improve-prompt/skills/{coding,writing,analysis}/`, each carrying the same 4-step output process as `start` but only its own component table, with a `description` scoped to explicit slash-command invocation so it doesn't compete with `start`'s auto-trigger. `start` itself is untouched. The repo's two test tiers (`scripts/test.sh` static checks, `scripts/lib/lifecycle.sh` real install/uninstall) are extended to cover the new skills, including a latent bug fix in `lifecycle.sh` that the new skills would otherwise trip.

**Tech Stack:** Markdown (`SKILL.md` frontmatter + body), Bash (`scripts/test.sh`, `scripts/lib/lifecycle.sh`), JSON (`plugin.json`), no build step.

## Global Constraints

- Each new skill hard-locks its variant: no "pick the variant" language, no inference, no fallback to General. (spec: Design → Skill content)
- Each new skill is fully self-contained — no shared/include file across skills. (spec: Non-goals)
- Each new skill's component table is copied **verbatim** from `start`'s existing tables — do not rephrase. (spec: Design → Skill content)
- Each new skill's `description` is scoped to "explicitly invokes `/improve-prompt:<name>`" — not the broad "wants to improve/rewrite a prompt" wording `start` uses — so it stays reachable via slash command only. (spec: Design → Auto-trigger scoping)
- `start`'s `SKILL.md` is not modified. (spec: Non-goals)
- Version bump to `1.2.0` (minor, new functionality) across `plugin.json` and `CITATION.cff`, plus a `CHANGELOG.md` `### Added` entry — all three must agree, since `scripts/test.sh` asserts version consistency across them. (spec: Docs & versioning; scripts/test.sh:68-79)
- No manual git tag/release — CI cuts it automatically on push to master. (spec: Docs & versioning)

---

### Task 1: Extend Tier 1 static test to expect the 3 new skills (RED)

**Files:**
- Modify: `scripts/test.sh:81-100`

**Interfaces:**
- Produces: `EXPECT_SKILLS` bash array `(start coding writing analysis)`, consumed by later tasks' verification runs (just re-running `./scripts/test.sh`, no code dependency).

- [ ] **Step 1: Replace the single-skill layout check with a loop over the expected skill set**

Current lines 81-100 of `scripts/test.sh`:

```bash
# --- 3 & 4. Skill layout -----------------------------------------------------
printf "\nSkill layout\n"
skill_md="$PLUGIN_DIR/skills/$EXPECT_SKILL/SKILL.md"
if [ -f "$skill_md" ]; then
  ok "skill file exists at skills/$EXPECT_SKILL/SKILL.md"
  skill_name="$(sed -n -E 's/^name:[[:space:]]*(.*)$/\1/p' "$skill_md" | head -1)"
  if [ "$skill_name" = "$EXPECT_SKILL" ]; then
    ok "SKILL.md frontmatter name is '$EXPECT_SKILL'"
  else
    bad "SKILL.md frontmatter name is '$skill_name', expected '$EXPECT_SKILL'"
  fi
else
  bad "missing skill file" "$skill_md not found"
fi

if [ -d "$PLUGIN_DIR/skills/improve-prompt" ]; then
  bad "stale skills/improve-prompt/ directory still present" "should have been renamed to skills/$EXPECT_SKILL/"
else
  ok "no stale skills/improve-prompt/ directory"
fi
```

Replace with:

```bash
# --- 3 & 4. Skill layout -----------------------------------------------------
printf "\nSkill layout\n"
EXPECT_SKILLS=(start coding writing analysis)
for skill in "${EXPECT_SKILLS[@]}"; do
  skill_md="$PLUGIN_DIR/skills/$skill/SKILL.md"
  if [ -f "$skill_md" ]; then
    ok "skill file exists at skills/$skill/SKILL.md"
    this_name="$(sed -n -E 's/^name:[[:space:]]*(.*)$/\1/p' "$skill_md" | head -1)"
    if [ "$this_name" = "$skill" ]; then
      ok "SKILL.md frontmatter name is '$skill'"
    else
      bad "SKILL.md frontmatter name is '$this_name', expected '$skill'"
    fi
  else
    bad "missing skill file" "$skill_md not found"
  fi
done

if [ -d "$PLUGIN_DIR/skills/improve-prompt" ]; then
  bad "stale skills/improve-prompt/ directory still present" "should have been renamed to skills/$EXPECT_SKILL/"
else
  ok "no stale skills/improve-prompt/ directory"
fi
```

Note: the "Derived command" section right after this (lines 102-115) reads a `skill_name` variable that the old code set — it now uses the untouched `EXPECT_SKILL="start"` constant directly instead, so it is unaffected by this loop rename (`skill_name` → `this_name`). Leave lines 102-115 exactly as they are; they already only reference `EXPECT_SKILL`, `EXPECT_COMMAND`, and `EXPECT_PLUGIN`.

- [ ] **Step 2: Run the script and confirm it fails on the 3 missing skills**

Run: `./scripts/test.sh`

Expected: exit code 1. Output includes, under "Skill layout":

```
  FAIL missing skill file
       plugins/improve-prompt/skills/coding/SKILL.md not found
  FAIL missing skill file
       plugins/improve-prompt/skills/writing/SKILL.md not found
  FAIL missing skill file
       plugins/improve-prompt/skills/analysis/SKILL.md not found
```

The `start` checks and everything else still pass.

- [ ] **Step 3: Commit**

```bash
git add scripts/test.sh
git commit -m "test: expect coding/writing/analysis skills in Tier 1 static checks"
```

---

### Task 2: Create the `coding` skill

**Files:**
- Create: `plugins/improve-prompt/skills/coding/SKILL.md`

**Interfaces:**
- Produces: skill `name: coding`, invoked as `/improve-prompt:coding`.

- [ ] **Step 1: Write the skill file**

Create `plugins/improve-prompt/skills/coding/SKILL.md`:

```markdown
---
name: coding
description: Use when the user explicitly invokes /improve-prompt:coding to rewrite a coding-related draft prompt for Claude. Always applies the Coding lens — does not infer or switch variants. Produces two improved variants plus a recommendation.
---

# Improve Prompt — Coding

Rewrite the user's draft prompt into a clearer, more effective one for
Claude, using the Coding lens below. Do not infer or switch variants —
always apply this table.

## Process

Structure the response with these headings, in this order, so the reader can
see exactly where each part starts and ends:

1. `## Ambiguities & Assumptions` — list anything ambiguous or missing in the
   user's prompt, plus any assumptions you're making. Ask if something is
   blocking; otherwise state the assumption and continue.
2. `## Approach` — briefly explain your approach.
3. Two improved versions, each under its own heading:
   - `## Variant A — <short label>` followed by the rewrite in a code block.
   - `## Variant B — <short label>` followed by the rewrite in a code block.
   Variant A is your best, tightest rewrite; Variant B is an alternative with
   a different angle. Give each variant a short descriptive label instead of
   leaving it generic.
4. `## Recommendation` — which variant to use and why (2-3 sentences).

Use the table below as a checklist — include a component only when it adds
real signal, and note briefly when you skip one. Never invent facts,
requirements, APIs, quotes, or conclusions not present in the user's prompt
or provided context.

| Component    | Meaning                                             | Question |
| ------------ | --------------------------------------------------- | -------- |
| Role         | e.g. senior engineer in <language/framework>        | Who      |
| Task         | The change/feature/fix, stated precisely            | What     |
| Context      | Stack, versions, file paths, existing patterns      | With     |
| Format       | Diff vs full file, tests included?, comments?       | Shape    |
| Constraints  | No new deps, match existing style, don't touch X    | Limits   |
| Goal         | The behavior/outcome the code must achieve          | Why      |
| Instructions | Only if a real sequence exists (e.g. TDD steps)     | How      |
| Success      | How correctness is verified (tests, edge cases)     | Proof    |
```

- [ ] **Step 2: Run Tier 1 and confirm the coding checks now pass**

Run: `./scripts/test.sh`

Expected: the two `coding` lines under "Skill layout" now show:

```
  PASS skill file exists at skills/coding/SKILL.md
  PASS SKILL.md frontmatter name is 'coding'
```

`writing` and `analysis` still fail (unchanged from Task 1).

- [ ] **Step 3: Commit**

```bash
git add plugins/improve-prompt/skills/coding/SKILL.md
git commit -m "feat: add /improve-prompt:coding variant-locked command"
```

---

### Task 3: Create the `writing` skill

**Files:**
- Create: `plugins/improve-prompt/skills/writing/SKILL.md`

**Interfaces:**
- Produces: skill `name: writing`, invoked as `/improve-prompt:writing`.

- [ ] **Step 1: Write the skill file**

Create `plugins/improve-prompt/skills/writing/SKILL.md`:

```markdown
---
name: writing
description: Use when the user explicitly invokes /improve-prompt:writing to rewrite a writing-related draft prompt for Claude. Always applies the Writing lens — does not infer or switch variants. Produces two improved variants plus a recommendation.
---

# Improve Prompt — Writing

Rewrite the user's draft prompt into a clearer, more effective one for
Claude, using the Writing lens below. Do not infer or switch variants —
always apply this table.

## Process

Structure the response with these headings, in this order, so the reader can
see exactly where each part starts and ends:

1. `## Ambiguities & Assumptions` — list anything ambiguous or missing in the
   user's prompt, plus any assumptions you're making. Ask if something is
   blocking; otherwise state the assumption and continue.
2. `## Approach` — briefly explain your approach.
3. Two improved versions, each under its own heading:
   - `## Variant A — <short label>` followed by the rewrite in a code block.
   - `## Variant B — <short label>` followed by the rewrite in a code block.
   Variant A is your best, tightest rewrite; Variant B is an alternative with
   a different angle. Give each variant a short descriptive label instead of
   leaving it generic.
4. `## Recommendation` — which variant to use and why (2-3 sentences).

Use the table below as a checklist — include a component only when it adds
real signal, and note briefly when you skip one. Never invent facts,
requirements, APIs, quotes, or conclusions not present in the user's prompt
or provided context.

| Component    | Meaning                                          | Question |
| ------------ | ------------------------------------------------ | -------- |
| Role         | The voice/persona (e.g. tech journalist)         | Who      |
| Audience     | Who reads this and their expertise level         | For whom |
| Task         | What to write and its purpose                    | What     |
| Tone & Style | Formal/casual, brand voice, examples to match    | Feel     |
| Format       | Length, structure, headings, output medium       | Shape    |
| Context      | Source material, key points, background          | With     |
| Constraints  | Avoid jargon, no clichés, word limit, don't claim| Limits   |
```

- [ ] **Step 2: Run Tier 1 and confirm the writing checks now pass**

Run: `./scripts/test.sh`

Expected: the two `writing` lines under "Skill layout" now show:

```
  PASS skill file exists at skills/writing/SKILL.md
  PASS SKILL.md frontmatter name is 'writing'
```

`analysis` still fails (unchanged from Task 1).

- [ ] **Step 3: Commit**

```bash
git add plugins/improve-prompt/skills/writing/SKILL.md
git commit -m "feat: add /improve-prompt:writing variant-locked command"
```

---

### Task 4: Create the `analysis` skill

**Files:**
- Create: `plugins/improve-prompt/skills/analysis/SKILL.md`

**Interfaces:**
- Produces: skill `name: analysis`, invoked as `/improve-prompt:analysis`.

- [ ] **Step 1: Write the skill file**

Create `plugins/improve-prompt/skills/analysis/SKILL.md`:

```markdown
---
name: analysis
description: Use when the user explicitly invokes /improve-prompt:analysis to rewrite an analysis-related draft prompt for Claude. Always applies the Analysis lens — does not infer or switch variants. Produces two improved variants plus a recommendation.
---

# Improve Prompt — Analysis

Rewrite the user's draft prompt into a clearer, more effective one for
Claude, using the Analysis lens below. Do not infer or switch variants —
always apply this table.

## Process

Structure the response with these headings, in this order, so the reader can
see exactly where each part starts and ends:

1. `## Ambiguities & Assumptions` — list anything ambiguous or missing in the
   user's prompt, plus any assumptions you're making. Ask if something is
   blocking; otherwise state the assumption and continue.
2. `## Approach` — briefly explain your approach.
3. Two improved versions, each under its own heading:
   - `## Variant A — <short label>` followed by the rewrite in a code block.
   - `## Variant B — <short label>` followed by the rewrite in a code block.
   Variant A is your best, tightest rewrite; Variant B is an alternative with
   a different angle. Give each variant a short descriptive label instead of
   leaving it generic.
4. `## Recommendation` — which variant to use and why (2-3 sentences).

Use the table below as a checklist — include a component only when it adds
real signal, and note briefly when you skip one. Never invent facts,
requirements, APIs, quotes, or conclusions not present in the user's prompt
or provided context.

| Component    | Meaning                                            | Question |
| ------------ | -------------------------------------------------- | -------- |
| Role         | e.g. data analyst, strategist, domain expert       | Who      |
| Task         | The question to answer or decision to inform       | What     |
| Data/Context | Inputs, source, timeframe, definitions             | With     |
| Method       | Framework or lens (e.g. SWOT, cohort, root-cause)  | How      |
| Format       | Summary + detail, tables, bullets, viz?            | Shape    |
| Goal         | The decision this analysis feeds                   | Why      |
| Constraints  | No speculation beyond data, cite sources, scope    | Limits   |
| Rigor        | State assumptions, confidence, and caveats         | Trust    |
```

- [ ] **Step 2: Run Tier 1 and confirm ALL checks now pass**

Run: `./scripts/test.sh`

Expected: exit code 0, final line `N passed, 0 failed, S skipped` (S is 0 or 2 depending on whether the `claude` CLI is on `PATH` locally — the two manifest `--strict` checks skip without it; this is pre-existing behavior, not something this task changes).

- [ ] **Step 3: Commit**

```bash
git add plugins/improve-prompt/skills/analysis/SKILL.md
git commit -m "feat: add /improve-prompt:analysis variant-locked command"
```

---

### Task 5: Fix and extend Tier 2 lifecycle test for multiple skills

**Problem this fixes:** `scripts/lib/lifecycle.sh` currently assumes exactly one skill directory exists. Its derived-command check does `find "$newdir/skills" ... | head -1` to pick "the" skill directory. Once `analysis`, `coding`, `start`, and `writing` all exist, `find` returns them in whatever order the filesystem gives (typically alphabetical: `analysis` sorts before `start`), so `head -1` would pick `analysis` instead of `start`, and the check would compare `improve-prompt:analysis` against the hardcoded expectation `improve-prompt:start` — a spurious failure introduced by adding the new skills, not a real regression. This task replaces that single-item assumption with a set-equality check across all 4 expected skills.

**Files:**
- Modify: `scripts/lib/lifecycle.sh:15-19` (identity constants)
- Modify: `scripts/lib/lifecycle.sh:134-153` (feature-check block inside `run_lifecycle`)

**Interfaces:**
- Consumes: none new — `run_lifecycle` is called as-is by `scripts/smoke-lifecycle.sh` and `scripts/verify-release.sh`, unchanged.
- Produces: `LC_SKILLS` bash array replaces the old `LC_SKILL`/`LC_COMMAND` scalars. No other file reads those two removed variables (confirmed: only `lifecycle.sh` itself references `LC_SKILL`/`LC_COMMAND`; `verify-release.sh` and `smoke-lifecycle.sh` only call `run_lifecycle`).

- [ ] **Step 1: Replace the identity constants**

Current lines 15-19 of `scripts/lib/lifecycle.sh`:

```bash
LC_PLUGIN="improve-prompt"
LC_MARKET="improve-prompt-marketplace"
LC_SPEC="$LC_PLUGIN@$LC_MARKET"
LC_SKILL="start"
LC_COMMAND="improve-prompt:start"
```

Replace with:

```bash
LC_PLUGIN="improve-prompt"
LC_MARKET="improve-prompt-marketplace"
LC_SPEC="$LC_PLUGIN@$LC_MARKET"
LC_SKILLS=(start coding writing analysis)
```

- [ ] **Step 2: Replace the per-skill existence check and the derived-command check**

Current lines 134-153 of `scripts/lib/lifecycle.sh`:

```bash
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
```

Replace with:

```bash
  newdir="$cfg/plugins/cache/$LC_MARKET/$LC_PLUGIN/$newv"
  local skill
  for skill in "${LC_SKILLS[@]}"; do
    [ -d "$newdir/skills/$skill" ] \
      && ok "installed copy has skills/$skill/" \
      || bad "installed copy missing skills/$skill/" "$newdir"
  done

  if [ -d "$newdir/skills/improve-prompt" ]; then
    bad "stale skills/improve-prompt/ present" "$newdir/skills/improve-prompt"
  else
    ok "no stale skills/improve-prompt/ in installed copy"
  fi

  # The installed copy's skill dirs must be EXACTLY the expected set — no
  # extra, none missing. (Avoids relying on filesystem enumeration order,
  # which broke the old single-skill "pick the first one" assumption.)
  local actual_sorted expected_sorted
  actual_sorted="$(find "$newdir/skills" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null | sort)"
  expected_sorted="$(printf '%s\n' "${LC_SKILLS[@]}" | sort)"
  [ "$actual_sorted" = "$expected_sorted" ] \
    && ok "installed copy's skill dirs match expected set (${LC_SKILLS[*]})" \
    || bad "installed copy's skill dirs mismatch" "expected: $(printf '%s ' $expected_sorted) / actual: $(printf '%s ' $actual_sorted)"
```

- [ ] **Step 3: Run Tier 2 and confirm it passes**

Run: `./scripts/smoke-lifecycle.sh`

Expected: exit code 0, final line `N passed, 0 failed` (this requires the `claude` CLI on `PATH`; if it's not installed locally, skip this step — CI always has it via Tier 2's own install step, so this will still be verified on push).

- [ ] **Step 4: Commit**

```bash
git add scripts/lib/lifecycle.sh
git commit -m "fix: lifecycle test set-equality check for multiple skill dirs"
```

---

### Task 6: Update README documentation

**Files:**
- Modify: `README.md:25-26`
- Modify: `README.md:52-63`
- Modify: `README.md:192-212`

**Interfaces:** none (documentation only).

- [ ] **Step 1: Fix the now-inaccurate "a single entry" claim in Install**

Current `README.md:25-26`:

```markdown
Restart Claude Code (or start a new session) and confirm a single
`/improve-prompt:start` entry appears in the `/` menu.
```

Replace with:

```markdown
Restart Claude Code (or start a new session) and confirm four entries appear
in the `/` menu: `/improve-prompt:start`, `/improve-prompt:coding`,
`/improve-prompt:writing`, and `/improve-prompt:analysis`.
```

- [ ] **Step 2: Document the dedicated commands in "Using it"**

Current `README.md:52-63`:

```markdown
## Using it

- **With your draft inline:** `/improve-prompt:start fix my flaky pytest suite`
- **Command alone:** type `/improve-prompt:start`, then paste your draft next.
- **No command at all:** paste a draft and say *"make this prompt better"* — the
  skill auto-triggers.

Hint the variant explicitly if you want: `/improve-prompt:start coding ...`,
`/improve-prompt:start writing ...`, `/improve-prompt:start analysis ...`, or
`/improve-prompt:start general ...`. Otherwise it infers the best fit (defaulting to
General).
```

Replace with:

```markdown
## Using it

- **With your draft inline:** `/improve-prompt:start fix my flaky pytest suite`
- **Command alone:** type `/improve-prompt:start`, then paste your draft next.
- **No command at all:** paste a draft and say *"make this prompt better"* — the
  skill auto-triggers.

Hint the variant explicitly if you want: `/improve-prompt:start coding ...`,
`/improve-prompt:start writing ...`, `/improve-prompt:start analysis ...`, or
`/improve-prompt:start general ...`. Otherwise it infers the best fit (defaulting to
General).

Already know which variant you want? Use the dedicated command instead —
it hard-locks that variant with no inference step, even if the draft's
content looks like it could be something else:

- `/improve-prompt:coding <draft>`
- `/improve-prompt:writing <draft>`
- `/improve-prompt:analysis <draft>`

These are slash-command-only — unlike `start`, they don't auto-trigger from a
pasted draft without the command.
```

- [ ] **Step 3: Update the repo layout tree and Maintaining section**

Current `README.md:192-212`:

```markdown
## Repo layout

```
improve-prompt-plugin/
├── .claude-plugin/
│   └── marketplace.json                 # marketplace manifest (lists the plugin)
└── plugins/
    └── improve-prompt/
        ├── .claude-plugin/
        │   └── plugin.json              # plugin manifest (name, version, keywords)
        └── skills/
            └── start/
                └── SKILL.md             # the skill (command + auto-trigger)
```

## Maintaining

- Edit the skill at `plugins/improve-prompt/skills/start/SKILL.md`.
- Bump `version` in `plugins/improve-prompt/.claude-plugin/plugin.json` on each
  change so installs can pull updates.
- Push to GitHub, then run the **Update** commands above to pull the change.
```

Replace with:

```markdown
## Repo layout

```
improve-prompt-plugin/
├── .claude-plugin/
│   └── marketplace.json                 # marketplace manifest (lists the plugin)
└── plugins/
    └── improve-prompt/
        ├── .claude-plugin/
        │   └── plugin.json              # plugin manifest (name, version, keywords)
        └── skills/
            ├── start/
            │   └── SKILL.md             # auto-detect + hinted variants (command + auto-trigger)
            ├── coding/
            │   └── SKILL.md             # hard-locked Coding variant (command only)
            ├── writing/
            │   └── SKILL.md             # hard-locked Writing variant (command only)
            └── analysis/
                └── SKILL.md             # hard-locked Analysis variant (command only)
```

## Maintaining

- Edit the skills at `plugins/improve-prompt/skills/{start,coding,writing,analysis}/SKILL.md`.
- Bump `version` in `plugins/improve-prompt/.claude-plugin/plugin.json` on each
  change so installs can pull updates.
- Push to GitHub, then run the **Update** commands above to pull the change.
```

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "docs: document the new variant-locked commands"
```

---

### Task 7: Functional smoke test of the 3 new skills

**Files:** none (verification only — no code changes).

**Interfaces:**
- Consumes: the `coding`, `writing`, `analysis` skills created in Tasks 2-4.

- [ ] **Step 1: Invoke each new skill with a sample draft and check the output shape**

Use the `Skill` tool three times, once per new skill, each with a short
draft that fits its domain:

```
Skill(skill: "coding", args: "write a function that dedupes a list")
Skill(skill: "writing", args: "draft an email announcing a delay")
Skill(skill: "analysis", args: "compare two hosting options")
```

For each invocation, confirm the response:
- Uses the exact heading sequence `## Ambiguities & Assumptions` →
  `## Approach` → `## Variant A — ...` → `## Variant B — ...` →
  `## Recommendation`.
- Uses only that skill's own table components (e.g. `coding`'s output
  should reference Role/Task/Context/Format/Constraints/Goal/
  Instructions/Success — not Audience or Tone & Style from the Writing
  table, not Data/Context or Rigor from the Analysis table).
- Contains no variant-picking language (no mention of "General", no
  "infer the best fit" — that phrasing belongs only to `start`).

If any of these are off, fix the corresponding `SKILL.md` from Task 2, 3,
or 4 and re-invoke before continuing.

- [ ] **Step 2: Confirm `start` still auto-detects correctly (regression check)**

Invoke `Skill(skill: "start", args: "write a function that dedupes a list")`
and confirm it still goes through the variant-picking step (may state it's
inferring "Coding") rather than skipping straight to the table the way the
dedicated `coding` skill does. This confirms the new skills didn't
accidentally change `start`'s behavior.

No commit for this task — it's verification only, nothing to stage.

---

### Task 8: Version bump, changelog, and final verification

**Files:**
- Modify: `plugins/improve-prompt/.claude-plugin/plugin.json`
- Modify: `CHANGELOG.md`
- Modify: `CITATION.cff`
- Modify: `.claude-plugin/marketplace.json`

**Interfaces:** none (metadata only).

- [ ] **Step 1: Bump the plugin version**

In `plugins/improve-prompt/.claude-plugin/plugin.json`, change:

```json
  "version": "1.1.2",
```

to:

```json
  "version": "1.2.0",
```

- [ ] **Step 2: Add a changelog entry**

At the top of `CHANGELOG.md`, immediately after the intro paragraph and before `## [1.1.2] - 2026-07-21`, insert:

```markdown
## [1.2.0] - 2026-07-21

### Added
- `/improve-prompt:coding`, `/improve-prompt:writing`, and
  `/improve-prompt:analysis` commands. Each hard-locks its variant — no
  inference, no fallback to General — for when you already know which lens
  you want. `start` is unchanged and continues to auto-detect/hint across
  all four variants.
```

- [ ] **Step 3: Sync CITATION.cff version**

In `CITATION.cff`, change:

```yaml
version: "1.1.2"
```

to:

```yaml
version: "1.2.0"
```

(`date-released` stays `"2026-07-21"` — same day.)

- [ ] **Step 4: Update the marketplace plugin description**

In `.claude-plugin/marketplace.json`, change:

```json
      "description": "Rewrite a draft prompt into a clearer, more effective one for Claude. Produces two improved variants plus a recommendation, tuned for coding, writing, analysis, or general tasks. Provides the /improve-prompt:start command and auto-triggers as a skill.",
```

to:

```json
      "description": "Rewrite a draft prompt into a clearer, more effective one for Claude. Produces two improved variants plus a recommendation, tuned for coding, writing, analysis, or general tasks. Provides /improve-prompt:start (auto-detect, auto-triggers as a skill) plus dedicated variant-locked commands: :coding, :writing, :analysis.",
```

- [ ] **Step 5: Run full Tier 1 verification**

Run: `./scripts/test.sh`

Expected: exit code 0. Under "Version consistency":

```
  PASS version matches across plugin.json, CITATION.cff, CHANGELOG (1.2.0)
```

All "Skill layout" checks for `start`, `coding`, `writing`, `analysis` pass.

- [ ] **Step 6: Commit**

```bash
git add plugins/improve-prompt/.claude-plugin/plugin.json CHANGELOG.md CITATION.cff .claude-plugin/marketplace.json
git commit -m "Release v1.2.0: add coding/writing/analysis variant-locked commands"
```

Do not tag or create a GitHub release manually — pushing this commit to
`master` triggers CI, which cuts the `v1.2.0` tag and release automatically
once Tier 1 and Tier 2 both pass.
