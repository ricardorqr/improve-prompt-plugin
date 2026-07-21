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
