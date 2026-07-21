# Variant-locked commands: `/improve-prompt:coding`, `:writing`, `:analysis`

## Problem

`start` already supports variant hints (`/improve-prompt:start coding ...`),
but it still infers/can fall back to General if the hint is ambiguous or the
pasted content doesn't clearly match. Users who already know they want the
Coding, Writing, or Analysis lens have no way to force it — they always go
through `start`'s inference step.

## Goal

Add three new commands that each hard-lock a single variant: no inference,
no fallback to General, no variant-picking step at all. Given a prompt, they
apply that variant's component table unconditionally.

## Non-goals

- Not changing `start`'s behavior — it stays exactly as-is (auto-detect +
  hints across all four variants).
- Not deduplicating the shared 4-step process text across skill files. The
  plugin's existing pattern is one self-contained `SKILL.md` per skill; this
  spec keeps that pattern rather than introducing a shared/include file.
- Not making the new skills auto-trigger from a pasted draft without the
  slash command.

## Design

### File layout

```
plugins/improve-prompt/skills/
├── start/SKILL.md       (unchanged)
├── coding/SKILL.md       (new)
├── writing/SKILL.md      (new)
└── analysis/SKILL.md     (new)
```

Each new skill directory becomes both a slash command
(`/improve-prompt:coding`, etc.) and a skill entry, the same mechanism
`start` already uses — no separate command manifest is needed.

### Skill content

Each new `SKILL.md`:

- Keeps the same 4-step output process as `start`
  (`## Ambiguities & Assumptions` → `## Approach` →
  `## Variant A — <label>` / `## Variant B — <label>` → `## Recommendation`).
- Drops `start`'s variant-picking preamble entirely. There is only one
  variant; it is never inferred or switched.
- Inlines only that skill's own component table (Coding, Writing, or
  Analysis) from `start`'s existing table set — copied verbatim, not
  rephrased, so the three lenses stay consistent with `start`'s definitions.
- Frontmatter `name` is the bare variant name (`coding`, `writing`,
  `analysis`).

Template for `coding/SKILL.md` (the other two follow the same shape with
their own table):

```markdown
---
name: coding
description: Use when the user explicitly invokes /improve-prompt:coding to
  rewrite a coding-related draft prompt for Claude. Always applies the Coding
  lens — does not infer or switch variants. Produces two improved variants
  plus a recommendation.
---

# Improve Prompt — Coding

Rewrite the user's draft prompt into a clearer, more effective one for
Claude, using the Coding lens below. Do not infer or switch variants — always
apply this table.

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

### Auto-trigger scoping

The `description` field is scoped to explicit invocation ("Use when the user
explicitly invokes /improve-prompt:coding...") rather than `start`'s broad
"Use when the user wants to improve, rewrite, or optimize a prompt..."
wording. This keeps the new skills from competing with `start` to
auto-trigger on a generic pasted draft — they're reachable via slash command
only, per the decision to keep auto-trigger behavior exclusive to `start`.

## Docs & versioning

- `README.md`: document the 3 new commands in the Install/Using-it sections
  and the repo-layout tree, following the same style used for `start`.
- `CHANGELOG.md`: add a `[1.2.0]` entry under `### Added` describing the new
  commands.
- `plugins/improve-prompt/.claude-plugin/plugin.json`: bump `version` to
  `1.2.0` (new functionality = minor bump per semver).
- No manual tag/release — CI cuts the release automatically on push to
  master (confirmed prior behavior; do not do this by hand).

## Testing

Per `superpowers:writing-skills`, this is a Reference-type skill change (no
discipline/behavior-shaping content, just a fixed lookup table + process),
so the applicable test is a retrieval/application scenario, not a
pressure-scenario suite:

- For each new command, feed a draft prompt in that domain and confirm the
  output uses the correct table components (no variant-picking language, no
  fallback to General) and follows the 4-step heading structure.
- Confirm `start` continues to auto-detect/hint correctly across all four
  variants (regression check — its file is unchanged, but verify no
  cross-skill interference).
