---
name: start
description: Use when the user wants to improve, rewrite, or optimize a prompt for Claude — including when they paste a draft prompt and ask for a better version, or invoke /improve-prompt:start. Produces two improved variants plus a recommendation, tuned for coding, writing, analysis, or general tasks.
---

# Improve Prompt

Rewrite the user's draft prompt into a clearer, more effective one for Claude.
Pick the variant matching the task (default to General if unclear;
infer from the prompt's content when obvious):

- **General** — anything that doesn't fit neatly below.
- **Coding** — writing/changing/debugging code.
- **Writing** — prose, docs, marketing, comms.
- **Analysis** — answering a question or informing a decision from data.

## Process (all variants)

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
   a different angle. Give each variant a short descriptive label (e.g. "Design
   Brief", "Comparative Evaluation") instead of leaving it generic.
4. `## Recommendation` — which variant to use and why (2-3 sentences).

Use the relevant table below as a checklist — include a component only when it
adds real signal, and note briefly when you skip one. Never invent facts,
requirements, APIs, quotes, or conclusions not present in the user's prompt or
provided context.

### General

| Component    | Meaning                          | Question |
| ------------ | -------------------------------- | -------- |
| Role         | The persona Claude should adopt  | Who      |
| Task         | What you want Claude to do       | What     |
| Context      | Background needed to do it well  | With     |
| Format       | Exact shape of the output        | Shape    |
| Constraints  | What Claude must NOT do          | Limits   |
| Goal         | The underlying objective         | Why      |
| Instructions | A sequence — only if one exists  | How      |

### Coding

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

### Writing

| Component    | Meaning                                          | Question |
| ------------ | ------------------------------------------------ | -------- |
| Role         | The voice/persona (e.g. tech journalist)         | Who      |
| Audience     | Who reads this and their expertise level         | For whom |
| Task         | What to write and its purpose                    | What     |
| Tone & Style | Formal/casual, brand voice, examples to match    | Feel     |
| Format       | Length, structure, headings, output medium       | Shape    |
| Context      | Source material, key points, background          | With     |
| Constraints  | Avoid jargon, no clichés, word limit, don't claim| Limits   |

### Analysis

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
