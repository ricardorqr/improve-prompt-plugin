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
