# F37 — Adaptive workflows per session

## Problem it solves

A fixed chain of roles made cost grow with the number of steps rather than with
the actual work. A failure found by a linter or a test could end up orphaned:
somebody saw it, but the flow moved on toward irrelevant roles or restarted the
whole sequence.

## Decision

The session keeps `workflowId` as a reference to the chosen workflow, but the
workflow declares intent, type, owner, capabilities with stable IDs, mandatory
context, quality gates, and reformulation/delegation limits. Each capability
defines a title, an instruction, a default role, dependencies, and whether
activation is required or optional. On start, the engine creates a
`ResolutionCase` with only the required capabilities; optional ones activate if
evidence makes them necessary. The rail's `available` state allows activating
them explicitly without restarting the case.

The bug, migration, and roadmap presets are editable templates, not branches
hardcoded in the engine. Modifying a capability changes the shared workflow;
assigning a concrete agent from the panel creates an override for that project
only. The preflight persists the resolved `ownerProfileId` on each node.

For migrations, the matrix of model, serialization, persistence, existing data,
callers, compatibility, tests, and UI must be closed completely. "Not
applicable" requires a justification.

## Localized replanning

A structured finding carries source, summary, and fingerprint. It pauses the
affected node, not the whole case. The same fingerprint cannot be retried
without a change; two reformulations without progress block the case, with the
evidence and concrete alternatives.

There is no execution compatibility for inherited chains, no progress by index,
and no control for walking the workflow again.

## Preflight and subagents

Before executing, the preflight confirms skills, rules, knowledge bases, an
agent per capability, and the provider's credentials. If anything mandatory is
missing, the case blocks without spending tokens. Both the injected context and
each missing item are persisted in the case and drawn from that same source.
Claude may use up to two subagents, only for research, impact inventory, or
verification; the owner remains the only writer and must synthesize their
results. Codex runs the same graph without that internal delegation.

## Right-hand panel

The panel keeps the product's visual representation at 272 px: a `WORKFLOW IN
PROGRESS` header, progress, the rail, and rows with state, agent, provider,
model, effort, consultations, findings, and evidence. Optional rows that were
not activated read `available`, and on closing, `not required`. Below appear
skills, rules, and knowledge; the required ones are identified, and the
project's extras are added or removed right there. A node that is running or
finished is locked, to preserve its traceability.

## Migrating stored data

On detecting earlier configurations, Keel exports the full raw catalog with a
date, outside the active catalog, and rewrites each workflow keeping its name,
content, and agents as capabilities. Only diagnosis, implementation, and
closure remain required; specialized reviews become available. The backup is
neither an execution path nor a compatibility adapter.

## Deletion and referential integrity

Deleting a workflow removes it from the catalog and, in the same operation,
removes its ID from the workflows assigned to each project, from the default
workflow, from the per-capability overrides, and from the sessions that still
named it. Sessions keep messages, evidence, and their materialized
`ResolutionCase`; they lose only the reference that can no longer be resolved.
If the project keeps other workflows, the first becomes its new default. When
loading data, Keel also detects and persists the cleanup of broken references
left by earlier versions.
