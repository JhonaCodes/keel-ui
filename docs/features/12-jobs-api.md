# F12 — Local scheduled-jobs API

## What it is

An HTTP endpoint on loopback so that EXTERNAL schedulers (cron, keel, scripts)
can open sessions in a project. Scheduling lives outside the app — this is the
socket.

## Contract

- Base: `http://127.0.0.1:<port>` (preferred fixed port 47821; if taken, an
  ephemeral one — the current one is shown in Settings).
- Auth: `Authorization: Bearer <token>` — a persisted token, visible and
  regenerable in Settings → Scheduled-jobs API.
- `POST /projects/<name>/sessions` with `{"prompt": "..."}` → creates a NEW
  session in that project, sends the prompt (starting the project's default
  workflow: a scheduled job has nobody to pick another one), and answers 202
  with `{sessionId}`. 409 if the project has no working folder; 404 if it does
  not exist.
- `GET /sessions/<id>` → `{status, isRunning, costUsd, messages}`.

## Cron example

```
0 9 * * 1 curl -s -X POST -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"prompt":"Generate the weekly report"}' \
  http://127.0.0.1:47821/projects/reports/sessions
```

## The old routes still answer

When a station became a project and its task a session, the routes followed.
But this is the app's only HTTP surface: out there may be a cron written months
ago that has no reason to learn that we changed the words in here.

`POST /stations/<name>/tasks` and `GET /tasks/<id>` still work, with no warning
and no difference. They are deprecated: what gets documented and what gets
written new is `/projects` and `/sessions`.

## Limits

- Loopback only (never exposed to the network).
- Creating the session makes it the ACTIVE session of that project in the UI.
