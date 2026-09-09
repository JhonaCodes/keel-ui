# F49 — Chat with filters, subagents in view, retry, and a persisted live turn

## Problem it solves

A session's thread was a single stream with no navigation: with four agents and
two hundred messages, the only way to see "what the auditor said" was to scroll.
Subagents did not exist in the chat at all (only on the Map). Each message's
chip read `resolution node: code-audit`, the raw id. An engine error message
offered nothing beyond "write something". And the live turn was not saved:
reopening the app mid-turn showed the session running with nobody running, and
whatever had been reasoned was lost. On top of that, with Opus, "thinking" with
no text looked like a hang.

## Decision

**Filters in the view.** `ThreadFilter`
(`modules/projects/model/thread_entry.dart`) narrows the thread by author, by
node, with or without system messages, with or without subagents. It is local
state of the list, not of the session. With an author selected, the system
becomes noise and is hidden; the user's messages are always shown. The chip bar
appears when there is more than one member or there are nodes.

**Subagents in the thread.** `buildThreadEntries` accepts the session's
subagents and interleaves them by start time (`ThreadSubagent`), rendered by
`SessionSubagentCard`: type, parent, request, phase, elapsed time, and the
folded result. Seeing them where the conversation is read is what exposes a
parent that opened three tasks without a question.

**Title instead of id.** `nodeTitleFor(workflow, nodeId)` resolves the
capability's title (legacy aliases included); the chip reads "step: Audit" and
the node-change divider reads "next Deliver".

**Retry step.** An engine error message about a node, with the session stopped
and the case still open, offers «Retry "title"». `retryWorkNode` →
`ResolutionEngine.retryNode` (node back to `pending`, case back to `active`) →
`resumeWorkflow`. It covers the watchdog's cut, a blocked case, and the turn
that died when the app closed.

**Persisted live turn.** `SessionLiveTurn` has JSON and travels in
`Session.toJson`. On revival (`revivedSession`), a turn left alive becomes a
system message carrying the phase and whatever was reasoned up to that point,
and is then cleared. The session no longer shows as running with nobody running.

**"Thinking" with no text.** The live-turn strip reads "thinking (this model does
not expose its reasoning live)" when the phase is thinking and no text arrived:
the CLI cannot be forced to emit it, but it can be said that this is not a hang.

## How to verify it

- `test/projects/thread_entries_test.dart`: filter by author, by node, the
  subagent interleaved between the messages around it, node titles.
- `test/projects/resolution_engine_test.dart`: `retryNode` returns the node to
  pending and the case to active.
- `test/workflows/workflow_execution_test.dart`: the live turn survives disk and
  becomes a message on revival.
