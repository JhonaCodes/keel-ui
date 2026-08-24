+# 09 — Operational flows

## a) A ticket resolves through an adaptive case

Scenario: a Flutter project opens a bug workflow with a resolver owner and
mandatory test gates.

```mermaid
sequenceDiagram
    actor U as User
    participant S as Session
    participant P as Preflight
    participant O as Resolution owner
    participant G as Resolution graph

    U->>S: "Add offline support to cart"
    S->>P: validate owner, skills, rules, knowledge
    P-->>S: visible injected context
    S->>G: create triage → implementation → verification
    G->>O: triage
    O->>O: inspect code and tests
    G->>O: implementation
    O->>O: make the minimal change
    G->>O: verification
    O->>G: test/linter/contract evidence
    G-->>U: resolved, or a localized finding
```

If verification detects a type, linter, test, contract, or review failure, it
records a finding with a fingerprint. Only the affected node pauses and is
reformulated. An identical failure without a change is rejected; the case
blocks after its reformulation limit instead of replaying unrelated roles.

For a migration, the graph adds impact inventory and cannot close until model,
serialization, persistence, existing data, callers, compatibility, tests, and
UI are all addressed.

## b) One project asks another for something via an internal requirement

Scenario: `aulamas-app` needs an endpoint that lives in `connect-api`, a different project, managed by another team (or another role) in the same org.

```mermaid
sequenceDiagram
    actor U as User (in aulamas-app)
    participant AA as Session in aulamas-app
    participant REQ as REQ-0007
    participant CA as New session in connect-api

    U->>AA: "We need offers filtered by institution"
    AA->>AA: checks its own roadmap, finds no endpoint
    AA->>REQ: create_requirement(need, context)
    Note over REQ: connect-api IS registered as a project → created
    REQ-->>U: appears in Requirements, state "open"

    Note over U,CA: destination decides when to take — could be time
    U->>CA: "Take and evaluate" (opens the new session and navigates there)
    activate CA
    CA->>CA: evaluates against ITS roadmap before building anything
    CA->>REQ: record_verdict(blocked, "need to migrate the institution model first")
    deactivate CA

    REQ-->>AA: aulamas-app sees the verdict, without getting repo access
    Note over AA: aulamas-app keeps with other tasks meanwhile

    Note over CA: in another session, later
    CA->>CA: migrates the model, implements the endpoint
    CA->>REQ: reply_requirement("Done, GET /v2/offers?institution_id=")
    CA->>REQ: request_closure("implemented and in production")

    U->>REQ: close_requirement — only aulamas-app can
```

Key points: both threads, both plans, both folders never mix — the only thing crossing is the requirement ([F26](../features/26-requerimientos-internos.md)); taking opens a **new session**, doesn't reuse origin context; and **closing is always who opened it**'s decision, verified mechanically by the MCP server URL delivered to that turn, not by a prompt instruction the model could disobey — see the complete detail in [05 — Multiple projects](05-multiple-projects.md#internal-requirements-ask-another-project-for-work).

## c) Build a new agent, assign skills and MCPs, export it, and use it on another machine

Scenario: build a `code-auditor` agent to review security and style, with two skills, one rule, and a GitHub MCP, and share it with another machine (or another team member).

```mermaid
flowchart TD
    subgraph Maquina1["Machine A"]
        direction TB
        A1["Register profile<br>code-auditor, role: auditor"]
        A2["Create 2 skills:<br>checklist-owasp, style-guide"]
        A3["Create 1 rule:<br>no-merge-without-tests"]
        A4["Assign github MCP<br>(secret GITHUB_TOKEN referenced by name)"]
        A5["Test the integration<br>live — F28"]
        A6["Export → agent package"]

        A1 --> A2 --> A3 --> A4 --> A5 --> A6
    end

    A6 --> Zip["code-auditor.zip<br>manifest + profile + skills + rule + MCP<br>(secret name, not value)"]

    subgraph Maquina2["Machine B (another person)"]
        direction TB
        B1["Open the .zip"]
        B2["Auto security review<br>runs on ALL content"]
        B3{"High-severity finding?"}
        B4["Install stays disabled<br>until acknowledging finding"]
        B5["Install available"]
        B6["mergeCatalogJson: create or update by name"]
        B7["GITHUB_TOKEN secret left pending<br>load manually"]

        B1 --> B2 --> B3
        B3 -->|yes| B4 --> B6
        B3 -->|no| B5 --> B6
        B6 --> B7
    end

    Zip --> B1
```

Key points: an agent package includes **everything** it needs to work the same on the other side — skills, rule, MCP — but **never** the secret's value, only its name ([F33](../features/33-paquetes.md)); security review runs both on export (so who exports doesn't send a personal path by accident) and on import; and final install is the same "create or update by name" mechanism that vault and file backup use — one entry point to the catalog, not three different implementations ([F33](../features/33-paquetes.md)).

See the complete detail of each piece in [08 — Import, export, and packages](08-import-export-and-packages.md).

## Next step

To understand how all this differs from a single-agent code assistant in a terminal or IDE, continue with [10 — Differences from other tools](10-differences-from-other-tools.md).
