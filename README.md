# improve-prompt — Claude Code Plugin

[![CI](https://github.com/ricardorqr/improve-prompt-plugin/actions/workflows/test.yml/badge.svg)](https://github.com/ricardorqr/improve-prompt-plugin/actions/workflows/test.yml)

A Claude Code plugin that rewrites your draft prompts into stronger ones for
Claude. Given any prompt, it flags what's missing, then returns **two
improved variants plus a recommendation**, tuned for one of four task types:
General, Coding, Writing, or Analysis.

Once installed it works two ways:
- As a slash command — `/improve-prompt:start` (auto-detects the variant) or
  the dedicated `/improve-prompt:coding`, `:writing`, `:analysis` (hard-locks
  that variant), and
- As an **auto-triggering skill** (just paste a draft and ask to improve it —
  this only applies to `start`).

---

## Install

Add the marketplace once, then install the plugin:

```
/plugin marketplace add ricardorqr/improve-prompt-plugin
/plugin install improve-prompt@improve-prompt-marketplace
```

Restart Claude Code (or start a new session) and confirm four entries appear
in the `/` menu: `/improve-prompt:start`, `/improve-prompt:coding`,
`/improve-prompt:writing`, and `/improve-prompt:analysis`.

## Update

```
/plugin marketplace update improve-prompt-marketplace
/plugin install improve-prompt@improve-prompt-marketplace
```

## Uninstall

Uninstalling removes the **entire plugin** — all 4 skills and commands
(`start`, `coding`, `writing`, `analysis`) — in one atomic action. Nothing is
left behind.

```
/plugin uninstall improve-prompt@improve-prompt-marketplace
```

- **Disable instead of remove:** use the `/plugin` menu to toggle it off while
  keeping it installed.
- **Removing the marketplace** (`/plugin marketplace remove improve-prompt-marketplace`)
  only stops future installs/updates from this source; it does not uninstall an
  already-installed plugin.

---

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

### What you get back

1. A short list of ambiguities/missing info + any assumptions made
2. A one-line explanation of the approach
3. **Two rewritten prompts** in separate code blocks — (a) tightest rewrite, (b) a different angle
4. A recommendation on which to use and why

### Examples

Each example shows the vague draft you start with (**Before**) and one of the
improved prompts the skill returns (**After**). In practice you always get two
variants plus a recommendation — a single "After" is shown here for brevity.

#### Coding

Invoke:
```
/improve-prompt:start coding write a python function to dedupe a list
```

Or invoke the dedicated command directly (same result, no inference step):
```
/improve-prompt:coding write a python function to dedupe a list
```

**Before**
```
write a python function to dedupe a list
```

**After**
```
You are a senior Python engineer. Write a function `dedupe(items)` that
removes duplicates from a list while PRESERVING first-seen order.

Requirements:
- Assume elements are hashable; if a value is unhashable, raise TypeError
  with a clear message.
- Do not mutate the input; return a new list.
- Target Python 3.11+, standard library only.

Include a short docstring and 3 pytest cases: empty list, all-unique,
and duplicates interleaved with order-sensitivity (e.g. [3,1,3,2,1] -> [3,1,2]).
```

#### Writing

Invoke:
```
/improve-prompt:start writing draft an email telling the team the deploy is delayed
```

Or invoke the dedicated command directly (same result, no inference step):
```
/improve-prompt:writing draft an email telling the team the deploy is delayed
```

**Before**
```
draft an email telling the team the deploy is delayed
```

**After**
```
You are writing an internal email as the release owner. Audience: the
engineering team (technical, already aware a deploy was planned).

Task: tell them the deploy is delayed. Keep it under 120 words, direct and
non-alarming — no corporate filler.

Include, using placeholders where I haven't given specifics:
- The new target date/time: {{new_date}}
- The cause in one plain sentence: {{cause}}
- The impact on them and what (if anything) they need to do: {{impact}}

Tone: calm, accountable, no over-apologizing. End with where to ask questions.
```

#### Analysis

Invoke:
```
/improve-prompt:start analysis compare RDS vs self-managed Postgres for our app
```

Or invoke the dedicated command directly (same result, no inference step):
```
/improve-prompt:analysis compare RDS vs self-managed Postgres for our app
```

**Before**
```
compare RDS vs self-managed Postgres for our app
```

**After**
```
Act as a pragmatic infrastructure architect. Compare AWS RDS (managed) vs
self-managed PostgreSQL on EC2 for our application, to inform a build-vs-buy
decision.

Evaluate across: operational effort (backups, patching, HA/failover), cost at
our scale, performance/tuning control, security & compliance, and scaling path.

Present a comparison table (dimension | RDS | self-managed), then a
recommendation with the top 2-3 deciding factors. State the assumptions you're
making about scale, team size, and budget, and flag where the answer would flip
if those change. Don't speculate beyond what these inputs support.
```

#### No command / auto-trigger

You don't have to type the command — just paste a draft and ask. The skill
fires on its own and returns the same before/after + two-variant output.

**Before**
```
Make this prompt better: "summarize this doc"
```

**After (one variant)**
```
Summarize the document below for a reader who hasn't seen it. Produce:
- A 2-sentence TL;DR
- 3-5 bullet points covering the key decisions/takeaways
- Any open questions or action items it raises

Keep it under 150 words. Don't add facts that aren't in the document.

<document>
{{paste_document_here}}
</document>
```

#### Inline draft (default General variant)

If you don't name a variant, it infers the task type (defaulting to General):
```
/improve-prompt:start help me plan a weekly sandbox refresh runbook
```

---

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
