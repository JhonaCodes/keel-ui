# F10 — Recurring skill suggestions

## What it is

DETERMINISTIC detection (zero tokens, no model involved) of requests the user
repeats, with a proposal to turn them into a global skill.

## Mechanics (`integrations/prompt_insights/`)

1. Every user prompt (1:1 chats and the project channel; never auto-retries) is
   recorded normalized: lowercased, accents and punctuation stripped, ES/EN
   stopwords removed, tokens longer than 2 chars. The log is FIFO-capped at 500
   entries (`promptlog_`).
2. At launch — and after each relevant record — a greedy clustering pass runs by
   Jaccard similarity (threshold 0.55) over a 30-day window. A cluster with 3 or
   more requests produces a `SkillSuggestion` with a stable signature (its top
   tokens); a dismissed signature is never proposed again.
3. UI: a strip on the Skills screen with up to 3 pending suggestions —
   "N× · «example»" plus **Create skill** (opens the form prefilled as GLOBAL,
   with the samples as a draft) or **Dismiss**.

## Keel AI's role

None in the detection, deliberately — it is meant to be deterministic. The seed
tells Keel AI that the system makes suggestions, so it can write the final
content with `create_skill(global: true)` if the user asks it to.
