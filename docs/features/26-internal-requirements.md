# F26 — Requirements between projects

## Problem it solves

`northstar-web` needs an endpoint that lives in `horizon-api`. Until now the agent
wrote it in its thread and it died there: there was no way for that request to
reach the other project, nor to know afterward whether anybody had resolved it.

The easy way out would be giving the agent access to the other repo. That breaks
precisely the boundary that makes this work: rules and knowledge bases reach only a
project's members **so that one project does not know things about another** (F24).
An agent with two repos open starts reasoning about both, and one's decisions leak
into the other with nobody asking for it.

## The idea

A requirement is **the only thing that crosses**.

```
#northstar-web        │  the boundary │  #horizon-api
                      │               │
  session thread      │               │    session thread
  work plan           │  ┌─────────┐  │    work plan
  its TASKS/          │  │ REQ-0007│  │    its TASKS/
  its folder          │  │ need    │  │    its folder
  rules and knowledge │  │ context │  │    rules and knowledge
                      │  │ verdict │  │
   ✗ does not cross ──┼─→│ thread  │←─┼──── ✗ does not cross
                      │  └─────────┘  │
```

Everything that crosses goes through **a single function**,
`renderRequirementForTurn`. If anything from the origin's context slips in there,
the boundary falls silently: there is no error, just two projects starting to know
things about each other. That is the function to look at in any future change.

No CLI session is shared, no MCP server, no working directory.

## The asymmetry that holds it up

**Closing belongs to the project that opened it.** It is the only one that knows
whether what it needed is really there. The other side can *request* closure, with
a clear justification, and wait.

That is not asked for in a prompt: it is checked. The project comes from the URL the
MCP server was handed to the turn with, so **a turn on the target side has no way
to claim it is the origin**. The rule lives in the ViewModel and not in the button,
so it holds equally when the one trying is an agent and not a click.

On screen it shows where it matters: on the origin's side the button reads
**"Close"**; on the target's side, that same place reads **"Request closure"** and
demands text.

## The cycle

```
open ──> taken ──> in progress ──> answered ──> closed
  │         └─────────────────────────┘  (already solved)
  │                       ↑
  │                       └── the origin rejects and explains
  └──> external   (the target is marked 🔒: you resolve it yourself)
```

The target's verdict has four shapes, and the fourth is the one a ticket cannot
tell: **already solved, in another form**. The work exists, but in a different shape
from the one requested — `GET /v2/offers?institution_id=` instead of the endpoint
they asked for — and that is neither a "yes" nor a "no".

`blocked` forces naming what comes first. A blocked without that helps nobody:
whoever asked cannot even estimate when to ask again.

## You, in the middle

The thread reads **as markdown**: agents write it, and their headings, lists, and
bold text are part of what they meant. Each strip's color bar is a **border** and
not a column beside it — with `Row` + `CrossAxisAlignment.stretch` the little bar
demanded the height of a strip that lives in a scroll, meaning no height, and that
threw "RenderBox was not laid out" on every strip and every frame: with the whole
render tree dumped each time, the window became unresponsive until killed by hand.

Your entry in the thread **is seen by both sides**, and it is the only one an agent
does not write. It is the *"no, look, this is how it's done"* when both are eyeing
each other while each is half right.

## Calling one side over to talk

For a while the thread was a document: you wrote "does this apply?" and nothing
happened, because nobody was reading it. For somebody to answer you had to press
"Take and evaluate", which is not answering — it is opening an entire work session
for a two-line question.

The middle rung was missing. Now **`@` brings one side over to talk**: it lists both
projects' members, you name one, and it answers right there. The target says whether
it applies; the origin clarifies what it meant. Both, in the same thread, without
opening anything.

Without a mention nothing runs. Writing is still writing: a note both sides see,
without spending a turn on something you jotted down for yourself.

**That turn only reads.** It runs with no session — just like `ask_project`, and for
the same reason: a session is where work happens, and it has not been decided to
work yet — standing in the repo of whoever answers, with not one MCP server plugged
in. That last part is not a prompt promise: without the requirement's tools, that
turn **cannot** take it, rule on it, or convert it even if it wants to. It reads its
code and its roadmap, and answers.

What crosses is still the same as always: `renderRequirementForTurn`, with the
thread inside. A consulted agent sees the request and the conversation; it does not
see the other's session, nor its plan, nor its folder.

## What it ends in

An accepted requirement used to die in a text verdict: it was stated that yes, and
there was no record of **where**. `convert_to_task` closes that: the target chooses
which group of its roadmap it goes in and with what priority, and Keel writes the
`.md`.

Keel writes it and not the agent, and it is the only roadmap task that does not come
from a file tool. Three things a program does well and an agent does badly: the
number — the next free one in the folder, without overwriting or leaving gaps — the
name — a slug with no accents or spaces — and the exact format the reader expects.
What is the agent's is the judgment: **which group it goes in**. If the group does
not exist, the tool fails and says so; creating it would create a group with no
`README.md`, which breaks the format check in the same move.

The requirement stores which task it ended in, and the thread shows it. On one side
of the wall a closed conversation remains; on the other, work in the queue.

## They work in parallel, they do not answer each other

Taking a requirement opens a **new** session in the target project, titled with its
code, whose initial request is the rendered block plus the instruction to evaluate
**against its own roadmap before building anything**.

That it is a new session is not style: it is the only way for the target's work not
to drag anything from the asker's context.

And it runs on its own. The origin carries on with its own work and finds out when
there is an answer.

**"Take and evaluate" takes you to that session.** It is a button you pressed: the
rule that creating is not going holds for what starts on its own — a tool, the API
— not for this. Staying to look at the requirement after pressing is staying to
look at the side you already read, while the work starts on another screen.

Once taken, the button goes away and in its place remains **"Go to the session"**,
which is the only door back to the work the requirement started. It only appears if
that session still exists: a stored id does not guarantee that what it points at is
still there.

## The gate

An agent **cannot** open a requirement against a repo that is not registered as a
project. The tool fails with a message saying what to do, and the agent then
*states it* in its answer:

> An endpoint for offers by institution is missing, but **there is no project
> registered for `horizon-api`**, so I did not open any requirement. Register it and
> I will open it; otherwise it has to be resolved outside.

When you later register the project and tell it "here it is", it retries and works.
That is the difference between an agent that warns and one that invents a recipient
that does not exist.

If the target exists but is marked as not maintained (F24), the requirement **is
still created**, with state `external`: it is recorded and in plain sight, and
nobody takes it. Losing the request helps nobody.

## Asking is not requesting

`ask_project` is a different thing, and that is why it is a different tool: it asks
another project something — what an endpoint looks like, whether something exists —
without asking it for work. It runs a separate agent in that repo, read-only, and
returns **only its answer**.

**The answer crosses, not the access.** Whoever asks never receives that folder. It
is the difference between asking and moving in.

## The tools

| Tool | Who | What it does |
|---|---|---|
| `list_requirements` | both | Theirs, in both directions |
| `create_requirement` | origin | Opens one. Fails with no registered project |
| `take_requirement` | target | Takes it to evaluate |
| `record_verdict` | target | Leaves the ruling, before building |
| `reply_requirement` | both | Writes in the shared thread |
| `request_closure` | target | REQUESTS closure, with justification |
| `close_requirement` | **origin only** | Closes it |
| `convert_to_task` | target | Converts it into a task in ITS roadmap |
| `ask_project` | anyone | Asks without requesting work |

## What happens if you delete a project

Its requirements are **not deleted**: they are shared history and the other side
still has the right to see it. They are left marked and unclaimable.

## In the backup

They are included, because they are a decision and not one session's noise. They
travel by code (`REQ-0007`) and with the projects by name; ids and sessions belong
to this machine and do not leave.

On restore they are **created if missing and not overwritten if present**. A
requirement is a live conversation: restoring the backup's snapshot on top would
erase everything said since, which is exactly what one does not want from a backup.

## Verification

1. Ask an unregistered target: nothing is created and the agent says so. Register
   the project, retry, it is created.
2. The target takes it, evaluates against its roadmap, and leaves `blocked` naming
   what comes first. The origin sees it; its thread never appeared on the other
   side.
3. The target requests closure with a justification; `close_requirement` from the
   target is rejected, naming who can.
4. Write a correction in the middle: both sides see it.
5. A 🔒 project receives one: it is born `external` and nobody takes it.
6. `ask_project` answers about the other repo without the asker receiving access to
   that folder.
7. Back up and restore clean returns the requirements with their thread; restoring
   over one that kept conversing does not overwrite it.
8. `@` in the thread lists both projects' members and nobody else; naming one from
   the target makes it answer from its side, and one from the origin from its own.
   Writing without naming anybody runs no turn.
9. The target converts: the `.md` appears in its `TASKS/` with its `prioridad:`,
   `check_roadmap_format` still passes, and the thread shows what it ended in.
   Converting twice is rejected.
