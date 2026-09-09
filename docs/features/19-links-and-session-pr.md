# F19 — Clickable links and the session's PR

## Problem it solves

The last step of a flow ends up opening a pull request, and says so in the
thread: `https://github.com/org/repo/pull/312`. That line was dead text — you
had to select it, copy it, and paste it into the browser — and forty messages
later you could not even find it.

## Links

`GptMarkdown` only makes clickable what already arrives with link syntax, and
the URLs that matter arrive bare: `gh pr create` prints its own as-is.
`linkifyBareUrls` wraps them before rendering.

Two deliberate limits:

- **Nothing is touched inside a code block.** In there a URL is part of a
  command or of output, not something to go visit.
- **`http(s)` only.** Whoever writes the link is a model; `file://` or an app
  scheme would open things nobody asked for.

They open with `open`, the same path the documents of a knowledge base already
used — this is a macOS desktop app and the binary is always there, so one more
dependency bought nothing.

## `PR #N` in the header

If any message in the session names a GitHub pull request, the header shows its
number next to the context and the cost. One click opens it.

It is read from the messages, not from a field of the session's own: the PR is
opened by an agent with `gh` during its turn, and the thread is where that gets
stated. Storing it separately would be a second place where it can go stale. If
a session opened the PR and then redid it, the last one to appear wins — the
current one is the one further down the thread.

## The DELIVERY contract

Until now the app only guaranteed the click; what "delivering" meant was written
nowhere, and each flow invented it — merging, not opening a PR, or opening a new
one per cycle. It is now a section of the system prompt of every project turn
whose working directory has git (`_deliveryPrompt`):

- The result is delivered as a **DRAFT pull request** — never merged nor marked
  ready for review: the user decides that.
- First cycle that touches code: the session's own branch, commits there,
  `gh pr create --draft`. Following cycles: the SAME branch, the same PR.
- The full URL goes on its own line in the thread, outside code blocks — that is
  what makes it clickable and what feeds the `PR #N` chip.
- "Closing the last cycle without the PR URL in the thread is closing without
  delivering."

In a project without `.git` the section does not appear and nothing demands a PR.
Consultation turns do not carry it either: delivery belongs to whoever does the
work.

## What this does NOT do

The app does not open the PR itself. That remains an agent's job: the app does
not know the base branch, nor whether the gate returned GO, nor whether the repo
has a remote. What the app guarantees is the contract above in the prompt, and
that once the agent writes the URL down, getting there is one click.
