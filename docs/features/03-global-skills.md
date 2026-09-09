# F3 — Global skills

## What it is

A skill marked **global** (`Skill.isGlobal`) is injected into the system prompt
of EVERY agent on every turn — 1:1 chats (with or without a profile) and project
members alike — without being assigned to anyone.

## Where it is injected

- 1:1: `AgentsViewModel._resolveProfileSystemPrompt` — globals go FIRST, then
  the profile's system prompt, then its assigned skills, then its rules. A
  global skill that is also assigned is injected ONCE.
- Projects: `StationsViewModel._turnSystemPrompt` — same order, same
  deduplication rule.

## How one is created

- UI: the "Global skill" switch on the skill form; the list shows a `global`
  chip.
- Keel AI: `create_skill` accepts `global: true`; the fallback fenced block
  accepts the key `global: si|no`.
- The suggestion system (F10) creates its proposals as global.

## When to use it

Global = norms or knowledge that apply to the whole system (style, house rules,
business context). A role's specialties stay assigned skills.

## Cost

Every global skill travels in full on EVERY turn of EVERY agent. Prompt caching
makes that cheaper, but not free — keep them few and short.
