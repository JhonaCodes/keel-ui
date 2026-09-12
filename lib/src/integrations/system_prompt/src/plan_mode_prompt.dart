part of '../system_prompt.dart';

/// MODO PLAN, para los proveedores que no tienen uno propio.
///
/// Qué dice: este turno planifica y no ejecuta. Leé todo lo que necesites,
/// después contá cómo lo harías —qué archivos, qué cambios, en qué orden, qué
/// puede salir mal— y frená ahí. No escribas, no corras comandos que cambien
/// nada, y no arranques «la parte fácil» mientras tanto.
///
/// Quién lo usa: `codex_cli_runner` y el puente de los proveedores por API,
/// cuando el turno viene con `planMode`.
///
/// Por qué existe: el CLI de Claude tiene modo plan propio —`--permission-mode
/// plan`, con su prompt y su freno de verdad— y ahí este texto NO se agrega:
/// pelearía contra el del CLI. Codex y los proveedores por API no tienen nada
/// equivalente, así que el freno se arma con dos piezas: sacarles las tools de
/// escritura, y este texto que explica por qué no las tienen. Sin la
/// explicación, un agente sin `Write` se la pasa peleando con la herramienta
/// que le falta en vez de planificar.
///
/// El último párrafo es el que más trabaja: sin él, el agente cierra el turno
/// prometiendo «ahora lo implemento» y el usuario espera una segunda mitad que
/// nunca llega, porque el turno ya terminó.
const kPlanModePrompt =
    '$kPlanningDiagramPrompt\n\n'
    'PLAN MODE — THIS TURN PLANS, IT DOES NOT BUILD. Read whatever you need '
    'to understand the problem: open files, search, inspect, run read-only '
    'commands. Then stop and describe how you would do the work.\n'
    'Do not create, edit, or delete a single file. Do not run a command that '
    'changes anything — no installs, no migrations, no git writes, no '
    'formatters. Do not start "the easy part" while you think. The write '
    'tools are absent from this turn on purpose; their absence is the '
    'instruction, not an obstacle to work around.\n'
    'A good plan names the files it would touch, says what changes in each '
    'and in what order, and is honest about what could go wrong or what you '
    'are unsure of. If the request is ambiguous enough that two readings lead '
    'to different work, say so and ask instead of guessing.\n'
    'In an assigned workflow node, finish its read-only contract and report '
    'the outcome so the engine can hand work to the next owner automatically; '
    'do not request another approval unless the contract requires one. '
    'For a standalone plan-only request, end with the plan and wait for the '
    'user to authorize implementation.';
