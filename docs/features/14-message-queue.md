# F14 — Writing while the agents work

## What it is

The composers of the individual chat, Keel AI, and project sessions do not lock
during a turn. You can write while the agents respond and save the message —
with its F13 images — without interrupting what you were drafting.

The `TextField` used to be disabled with `enabled: !agent.isStreaming` and
`sendMessage` bailed out with a mute `return`: the correction occurred to you
precisely while the model was working, and there was nowhere to write it.

## Why it is a QUEUE and not an injection

Both CLIs are one-shot per turn (`claude -p`, `codex exec`): there is no open
stdin to slip a message into mid-turn. So the message waits and goes out
afterward, instead of being lost or blocking input.

## Individual chat and Keel AI

1. Agent streaming + send → `AgentsViewModel.sendMessage` sees `isStreaming` and
   queues a `QueuedMessage{text, imagePaths}` into `Agent.queuedMessages`
   (transient, like `isStreaming`: NOT serialized; a queue only makes sense
   alongside the turn it was written during).
2. The queue is visible above the composer (`QueuedMessagesStrip`), with an X per
   message. A message that vanishes without a trace reads as a lost message.
3. When the turn ends, everything queued goes out as **ONE** turn: the texts are
   joined in order with a blank line between them, and the images are
   concatenated. The model reads them together, which is what "I sent you a
   correction while you were working" means.

## Project sessions

A session has its own persisted queue in `Session.queuedMessages`. Each
`SessionQueuedMessage` has a stable ID, text, attachments, a date, and a delivery
decision. It does not use list indices to edit or delete, because the queue can
advance at the same time the UI changes.

While the workflow is running, the composer stays enabled and the primary button
reads **Save for later**. The message stays visible above the field and offers
five operations:

- **Edit** changes the text without detaching its images.
- **Delete** removes the message and discards its stored attachments.
- **Send now** requests stopping the current turn and delivers the message only
  once the previous process actually returned control.
- **Send when it finishes** lets the turn end normally and dispatches the message
  next.
- **Keep waiting** cancels an earlier scheduling and returns the message to
  manual control.

Automatic messages go out one at a time. The next does not start until the
previous one finished; two simultaneous writers are never opened over the same
workspace. Messages on manual hold are not sent merely because a session was
stopped.

Switching screens leaves the queue on the session. On app revival, a decision
that depended on a previous process becomes a manual hold: the process no longer
exists and the app does not pretend it can still "finish".

## Stop is a deliberate exception in the individual chat

If you stopped the turn with Stop, the queue does **not** fire on its own:
stopping is "I'm taking control", and starting a new turn right there would be
the opposite of what you asked for. The messages stay in view and the strip
offers **"Send now"** while the agent is free.

Implementation: `sendMessage` marks `wasStopped` when the event loop cuts on
stop, and only calls `sendQueuedMessages` if it finished normally.

## The composers' buttons

During a turn two intentions coexist, so there are two buttons: **Stop**
(outlined) and **Save for later** (filled, with a clock icon). Saving does not
assume the user wants to interrupt, nor that they want to send automatically;
that decision is made on the message's visible row.

## The assistant's port and window

`ChatActions` gains `sendQueuedMessages(agentId)` and
`removeQueuedMessage(agentId, index)`; `BridgeChatActions` sends them as
`sendQueued` / `removeQueued`. `AssistantAgentSnapshot` carries `queuedMessages`
on the wire so the dedicated window shows the same strip.

## Technical limit

The runners are still one-shot. "Send now" does not inject text into an open
process: it cancels it, waits for it to close, and opens a new turn. That wait is
part of the single-writer-per-session guarantee.
