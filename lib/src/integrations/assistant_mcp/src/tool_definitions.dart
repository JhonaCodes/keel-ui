part of '../assistant_mcp_server.dart';

/// Same five actions the fenced-block mechanism already knows how to run —
/// see `assistant_action_executor.dart`. Deliberately no new scope here:
/// changing transport and scope in the same step would be hard to diagnose
/// if something broke.
final List<Tool> keelAiTools = _withCatalogChangeParameters([
  Tool(
    name: 'list_locked_items',
    description: 'Lista el registro persistente de elementos bloqueados.',
    inputSchema: ObjectSchema(properties: {}),
  ),
  Tool(
    name: 'lock_item',
    description:
        'Bloquea un elemento del catálogo. Como el registro está protegido, '
        'siempre pedirá permiso al usuario antes de escribir.',
    inputSchema: ObjectSchema(
      properties: {
        'kind': Schema.string(description: 'kind de get_item.'),
        'name': Schema.string(description: 'Nombre exacto del elemento.'),
        'change_intent': Schema.string(description: 'Qué cambio querés hacer.'),
        'change_reason': Schema.string(description: 'Por qué es necesario.'),
      },
      required: ['kind', 'name', 'change_intent', 'change_reason'],
    ),
  ),
  Tool(
    name: 'unlock_item',
    description:
        'Desbloquea un elemento del catálogo. SIEMPRE requiere permiso '
        'explícito del usuario.',
    inputSchema: ObjectSchema(
      properties: {
        'kind': Schema.string(description: 'kind de get_item.'),
        'name': Schema.string(description: 'Nombre exacto del elemento.'),
        'change_intent': Schema.string(description: 'Qué cambio querés hacer.'),
        'change_reason': Schema.string(description: 'Por qué es necesario.'),
      },
      required: ['kind', 'name', 'change_intent', 'change_reason'],
    ),
  ),
  Tool(
    name: 'create_skill',
    description:
        'Crea una skill de Keel AI (nombre + contenido en markdown). Si ya '
        'existe una skill con ese nombre, la reusa sin error.',
    inputSchema: ObjectSchema(
      properties: {
        'name': Schema.string(description: 'Nombre único de la skill.'),
        'content': Schema.string(
          description: 'Contenido en markdown de la skill.',
        ),
        'global': Schema.bool(
          description:
              'true = skill GLOBAL: la reciben todos los agentes en cada '
              'turno sin asignarla. false/omitido = solo agentes que la '
              'tengan asignada.',
        ),
      },
      required: ['name', 'content'],
    ),
  ),
  Tool(
    name: 'create_rule',
    description:
        'Crea una regla de Keel AI (nombre + contenido). Idempotente por '
        'nombre.',
    inputSchema: ObjectSchema(
      properties: {
        'name': Schema.string(description: 'Nombre único de la regla.'),
        'content': Schema.string(description: 'Contenido de la regla.'),
      },
      required: ['name', 'content'],
    ),
  ),
  Tool(
    name: 'create_hook',
    description:
        'Crea o actualiza un HOOK: un comando que ejecuta el CLI cuando '
        'ocurre un evento del turno. A diferencia de una regla —que es texto '
        'que el modelo puede desobedecer— un hook no pasa por el modelo y '
        'puede FRENAR lo que estaba por pasar (saliendo con código 2). '
        'Idempotente por nombre.',
    inputSchema: ObjectSchema(
      properties: {
        'name': Schema.string(
          description: 'Nombre único, en minúsculas, sin espacios.',
        ),
        'description': Schema.string(description: 'Qué hace y cuándo.'),
        'event': Schema.string(
          description:
              'Evento. Corren en claude Y codex: SessionStart, SessionEnd, '
              'UserPromptSubmit, PreToolUse, PermissionRequest, PostToolUse, '
              'PreCompact, PostCompact, SubagentStart, SubagentStop, Stop. '
              'Solo claude: Notification, PermissionDenied, '
              'PostToolUseFailure, FileChanged, InstructionsLoaded, '
              'StopFailure.',
        ),
        'command': Schema.string(
          description:
              'El comando a ejecutar. Recibe el evento como JSON por entrada '
              'estándar. Excluyente con tool_name.',
        ),
        'tool_name': Schema.string(
          description:
              'Nombre de una tool registrada que hace de cuerpo del hook. '
              'Excluyente con command.',
        ),
        'matcher': Schema.string(
          description:
              'Qué acota dentro del evento — el nombre de la herramienta en '
              'PreToolUse ("Bash", "Edit|Write"). Vacío = todo.',
        ),
        'timeout_seconds': Schema.int(
          description: 'Por defecto 10. Máximo 120.',
        ),
        'enforces': Schema.list(
          description: 'Nombres de reglas que este hook hace cumplir.',
          items: Schema.string(),
        ),
        'is_global': Schema.bool(
          description: 'Si corre para todos los agentes sin asignarlo.',
        ),
        'enabled': Schema.bool(description: 'Por defecto true.'),
      },
      required: ['name', 'event'],
    ),
  ),
  Tool(
    name: 'set_hook_enabled',
    description:
        'Prende o apaga un hook sin borrarlo. Es la palanca de emergencia: '
        'si un guardarraíl mal escrito dejó trabados a los agentes, apagarlo '
        'los destraba. A VOS los hooks no se te aplican, justamente para que '
        'puedas hacer esto.',
    inputSchema: ObjectSchema(
      properties: {
        'name': Schema.string(description: 'Nombre del hook.'),
        'enabled': Schema.bool(description: 'true para prender.'),
      },
      required: ['name', 'enabled'],
    ),
  ),
  Tool(
    name: 'delete_hook',
    description:
        'Elimina un hook del catálogo Y de todos los agentes y proyectos '
        'que lo tenían asignado. Lo que dejaba de pasar vuelve a poder pasar.',
    inputSchema: ObjectSchema(
      properties: {
        'name': Schema.string(description: 'Nombre del hook a eliminar.'),
      },
      required: ['name'],
    ),
  ),
  Tool(
    name: 'create_tool',
    description:
        'Crea una tool ejecutable: un script determinista (bash, python o '
        'dart) que un agente puede llamar como tool MCP real en vez de '
        'hacer ese trabajo a mano (parsear archivos, convertir formatos, '
        'calcular). El script recibe los argumentos de cada llamada como '
        'argv y reporta por stdout/stderr. Idempotente por nombre: si ya '
        'existe una tool con ese nombre, se reusa sin error. Para que un '
        'agente la pueda usar hay que asignársela con '
        'create_or_update_agent (tool_names).',
    inputSchema: ObjectSchema(
      properties: {
        'name': Schema.string(
          description:
              'Nombre único de la tool: minúsculas, sin espacios, solo '
              '[a-z0-9_-], máximo 32 caracteres.',
        ),
        'description': Schema.string(
          description:
              'Qué hace, cuándo usarla y qué significa cada argumento '
              'posicional — es lo que el agente lee para decidir llamarla.',
        ),
        'runtime': Schema.string(
          description: 'Runtime del script: "bash", "python" o "dart".',
        ),
        'code': Schema.string(
          description:
              'Código fuente completo del script. Recibe los argumentos '
              'como argv posicionales.',
        ),
        'timeout_seconds': Schema.int(
          description:
              'Tiempo máximo de ejecución en segundos (opcional, por '
              'defecto 60, máximo 600).',
        ),
        'secret_names': Schema.list(
          items: Schema.string(),
          description:
              'Secrets (por NOMBRE) que el script recibe como variables de '
              'entorno. Si alguno no existe, pedilo antes con '
              'request_secret.',
        ),
      },
      required: ['name', 'description', 'runtime', 'code'],
    ),
  ),
  Tool(
    name: 'request_secret',
    description:
        'Registra que el sistema necesita una clave/credencial (API key, '
        'token, etc.). Crea el secret como PENDIENTE: el VALOR solo lo puede '
        'cargar el usuario, con el botón «Cargar valor» de la pantalla de '
        'Secrets o del formulario de la tool/MCP que lo declara — nunca lo '
        'pidas por chat ni lo aceptes si te lo pegan (deciles que usen ese '
        'botón). Idempotente por nombre.',
    inputSchema: ObjectSchema(
      properties: {
        'name': Schema.string(
          description:
              'Nombre en formato variable de entorno: MAYÚSCULAS, números y '
              '"_" (ej: STRIPE_API_KEY).',
        ),
        'why': Schema.string(
          description: 'Para qué se necesita — se muestra al usuario.',
        ),
      },
      required: ['name', 'why'],
    ),
  ),
  Tool(
    name: 'register_mcp_server',
    description:
        'Registra un servidor MCP EXTERNO (gmail, drive, github, …) que '
        'después se asigna a agentes con create_or_update_agent '
        '(mcp_server_names). stdio: command+args+env; http: url+headers. '
        'Credenciales SIEMPRE por secret_env (nombre de secret registrado), '
        'nunca como literal. Idempotente por nombre (si existe, se '
        'actualiza).',
    inputSchema: ObjectSchema(
      properties: {
        'name': Schema.string(
          description:
              'Nombre único (minúsculas; las tools llegan como '
              'mcp__<nombre>__*).',
        ),
        'transport': Schema.string(description: '"stdio" o "http".'),
        'command': Schema.string(description: 'stdio: ejecutable.'),
        'args': Schema.list(
          items: Schema.string(),
          description: 'stdio: argumentos.',
        ),
        'env': Schema.object(
          properties: {},
          description:
              'stdio: variables de entorno NO sensibles (clave→valor '
              'literal).',
        ),
        'secret_env': Schema.object(
          properties: {},
          description:
              'stdio: clave de entorno → NOMBRE de secret registrado. El '
              'valor se resuelve al momento del turno.',
        ),
        'url': Schema.string(description: 'http: URL del servidor.'),
        'headers': Schema.object(
          properties: {},
          description: 'http: headers (clave→valor).',
        ),
      },
      required: ['name', 'transport'],
    ),
  ),
  Tool(
    name: 'list_mcp_catalog',
    description:
        'Las integraciones MCP que Keel conoce, con su configuración exacta, '
        'qué credencial pide cada una y su documentación oficial. MIRALO '
        'ANTES de registrar algo a mano: si está en el catálogo, '
        'install_mcp_integration lo instala con la configuración correcta y '
        'no hay que inventar el nombre de un paquete.',
    inputSchema: ObjectSchema(properties: {}),
  ),
  Tool(
    name: 'install_mcp_integration',
    description:
        'Instala una integración del catálogo por su id (ver '
        'list_mcp_catalog). Deja la referencia al secret puesta pero NO lo '
        'crea: el valor solo lo puede cargar el usuario, desde Secrets. '
        'Idempotente por nombre.',
    inputSchema: ObjectSchema(
      properties: {
        'catalog_id': Schema.string(
          description: 'El id de la ficha ("github", "linear", "slack"…).',
        ),
      },
      required: ['catalog_id'],
    ),
  ),
  Tool(
    name: 'delete_mcp_server',
    description: 'Elimina un servidor MCP externo por nombre.',
    inputSchema: ObjectSchema(
      properties: {
        'name': Schema.string(description: 'Nombre del MCP a eliminar.'),
      },
      required: ['name'],
    ),
  ),
  Tool(
    name: 'backup_system',
    description:
        'Respalda TODO el sistema (skills, reglas, tools, workflows, MCPs, '
        'agentes, proyectos, bases de saber y ajustes) en el '
        'keel-backup.zip de la carpeta del vault, lo commitea y lo sube al '
        'repo del vault: es un solo paso, no hay respaldo a medias. Nada '
        'respalda solo — esto corre cuando alguien lo pide. De los secrets '
        'viajan solo los nombres, nunca los valores; los hilos de chat no '
        'viajan.',
    inputSchema: ObjectSchema(properties: {}),
  ),
  Tool(
    name: 'restore_system',
    description:
        'Lee el keel-backup.zip del vault y fusiona TODO por nombre (crea lo '
        'que falta, actualiza lo existente), más los ajustes y los secrets '
        'que falten (sin valor). Los proyectos nuevos quedan sin carpeta de '
        'trabajo hasta que el usuario la elija en la UI.',
    inputSchema: ObjectSchema(properties: {}),
  ),
  Tool(
    name: 'sync_knowledge',
    description:
        'Actualiza una base de saber (git pull del repo, o releer la carpeta '
        'local) y la reindexa. Sin `base`, actualiza todas.',
    inputSchema: ObjectSchema(
      properties: {
        'base': Schema.string(description: 'Nombre de la base. Vacío = todas.'),
      },
    ),
  ),
  Tool(
    name: 'list_catalog',
    description:
        'Lista lo que YA existe en el sistema: skills, reglas, tools, '
        'agentes, workflows, proyectos, hooks y MCPs registrados, con su nombre y '
        'para qué sirve cada uno. USALA ANTES de asignarle cualquier cosa a '
        'un agente o a un proyecto: los nombres se referencian tal cual, y '
        'un nombre inventado se descarta. Sin `kind` devuelve todo el '
        'catálogo.',
    inputSchema: ObjectSchema(
      properties: {
        'kind': Schema.string(
          description:
              'Qué listar: skills, rules, tools, agents, workflows, '
              'projects, hooks, mcp_servers, knowledge_bases, o all (default).',
        ),
      },
    ),
  ),
  Tool(
    name: 'list_workflows',
    description:
        'Devuelve en una sola llamada el contrato adaptativo COMPLETO de '
        'todos los workflows registrados: intención, responsable, contexto, '
        'gates, límites y capacidades con sus dependencias. Usala para '
        'inventariar, comparar o rediseñar workflows sin perder elementos '
        'por depender de resúmenes. Si `names` se omite devuelve todos; si '
        'se envía, devuelve únicamente esos nombres exactos e informa cuáles '
        'no existen.',
    inputSchema: ObjectSchema(
      properties: {
        'names': Schema.list(
          description:
              'Nombres exactos opcionales. Omitido o vacío = todos los '
              'workflows registrados.',
          items: Schema.string(),
        ),
      },
    ),
  ),
  Tool(
    name: 'list_projects',
    description:
        'Devuelve en una sola llamada la configuración COMPLETA de todos los '
        'proyectos: miembros y motores efectivos, workflows disponibles y '
        'activo, asignaciones por nodo, contexto y sesiones con su workflow. '
        'Combinada con `list_workflows` permite detectar proyectos o sesiones '
        'que todavía referencian workflows inexistentes o anteriores. Si '
        '`names` se omite devuelve todos; si se envía, devuelve únicamente '
        'esos nombres exactos e informa cuáles no existen.',
    inputSchema: ObjectSchema(
      properties: {
        'names': Schema.list(
          description:
              'Nombres exactos opcionales. Omitido o vacío = todos los '
              'proyectos registrados.',
          items: Schema.string(),
        ),
      },
    ),
  ),
  Tool(
    name: 'get_item',
    description:
        'Devuelve el CONTENIDO COMPLETO de una cosa registrada: el texto '
        'entero de una skill o regla, el código de una tool, el contrato '
        'adaptativo de un workflow, o la configuración efectiva de un '
        'agente, proyecto o hook. Incluye IDs, dependencias, contexto, '
        'límites, asignaciones y overrides usados por el motor. '
        'Usala ANTES de actualizar cualquier cosa: los update reemplazan el '
        'contenido, así que sin leerlo primero pisás lo que había.',
    inputSchema: ObjectSchema(
      properties: {
        'kind': Schema.string(
          description:
              'Tipo: skill, rule, tool, agent, workflow, project, '
              'hook, mcp_server, knowledge_base, board, secret o '
              'lock_registry. Un tablero usa "proyecto · tablero".',
        ),
        'name': Schema.string(
          description: 'Nombre exacto (para un agente, su handle sin @).',
        ),
      },
      required: ['kind', 'name'],
    ),
  ),
  Tool(
    name: 'update_skill',
    description:
        'Reemplaza el contenido de una skill que ya existe (para crearla '
        'usá create_skill). El contenido se sustituye entero: leelo antes '
        'con get_item si querés conservar parte. Las asignaciones a agentes '
        'se mantienen porque van por nombre.',
    inputSchema: ObjectSchema(
      properties: {
        'name': Schema.string(description: 'Nombre de la skill a actualizar.'),
        'content': Schema.string(description: 'Contenido nuevo, completo.'),
        'new_name': Schema.string(
          description:
              'Renombrar (opcional). OJO: los agentes la referencian por '
              'nombre, así que renombrar rompe las asignaciones existentes.',
        ),
      },
      required: ['name', 'content'],
    ),
  ),
  Tool(
    name: 'update_rule',
    description:
        'Reemplaza el contenido de una regla existente. Mismo criterio que '
        'update_skill: sustituye todo, leé antes con get_item.',
    inputSchema: ObjectSchema(
      properties: {
        'name': Schema.string(description: 'Nombre de la regla.'),
        'content': Schema.string(description: 'Contenido nuevo, completo.'),
        'new_name': Schema.string(description: 'Renombrar (opcional).'),
      },
      required: ['name', 'content'],
    ),
  ),
  Tool(
    name: 'update_tool',
    description:
        'Actualiza una tool ejecutable existente. Solo se cambia lo que '
        'mandás: lo que omitas queda como estaba.',
    inputSchema: ObjectSchema(
      properties: {
        'name': Schema.string(description: 'Nombre de la tool.'),
        'description': Schema.string(description: 'Descripción nueva.'),
        'runtime': Schema.string(description: '"bash", "python" o "dart".'),
        'code': Schema.string(description: 'Código fuente nuevo, completo.'),
        'timeout_seconds': Schema.int(description: 'Timeout en segundos.'),
        'secret_names': Schema.list(
          items: Schema.string(),
          description: 'Secrets que recibe como variables de entorno.',
        ),
        'new_name': Schema.string(description: 'Renombrar (opcional).'),
      },
      required: ['name'],
    ),
  ),
  Tool(
    name: 'update_workflow',
    description:
        'Actualiza un workflow adaptativo completo. Leelo primero con '
        'get_item; los campos de contexto que envíes reemplazan los '
        'actuales.',
    inputSchema: ObjectSchema(
      properties: {
        'name': Schema.string(description: 'Nombre del workflow.'),
        'when_to_apply': Schema.string(
          description: 'Cuándo se usa este workflow.',
        ),
        'kind': Schema.string(
          description: '"general", "bug", "migration" o "roadmap".',
        ),
        'resolution_role': Schema.string(
          description:
              'Rol dueño del caso; vacío permite asignación automática.',
        ),
        'skills': Schema.list(
          items: Schema.string(),
          description:
              'Skills requeridas por el preflight. Reemplazan a las actuales.',
        ),
        'rule_names': Schema.list(
          items: Schema.string(),
          description: 'Reglas obligatorias del preflight.',
        ),
        'knowledge_base_names': Schema.list(
          items: Schema.string(),
          description: 'Bases de conocimiento obligatorias del preflight.',
        ),
        'quality_gates': Schema.list(
          items: Schema.string(),
          description:
              'Gates: analysis, focusedTests, compatibility, regression.',
        ),
        'max_replans': Schema.int(
          description: 'Máximo de reformulaciones, de 0 a 2.',
        ),
        'max_subagents': Schema.int(
          description:
              'Máximo de subagentes de lectura/verificación que cada NODO '
              'puede abrir en paralelo, de 0 a 6. El cupo es por nodo, no por '
              'corrida: un nodo no le consume el presupuesto al siguiente.',
        ),
        'max_review_cycles': Schema.int(
          description: 'Máximo total de ciclos auditoría/corrección, de 1 a 4.',
        ),
        'builds_roadmap': Schema.bool(
          description:
              'Si construye y valida el formato TASKS. Omitir conserva el valor actual.',
        ),
        'capabilities': Schema.list(
          items: ObjectSchema(
            properties: {
              'id': Schema.string(description: 'ID estable del nodo.'),
              'title': Schema.string(
                description: 'Título visible en el panel.',
              ),
              'instruction': Schema.string(
                description: 'Contrato del trabajo.',
              ),
              'role': Schema.string(description: 'Rol por defecto.'),
              'dependencies': Schema.list(items: Schema.string()),
              'activation': Schema.string(
                description: '"required" u "optional".',
              ),
              'independent': Schema.bool(
                description:
                    'True cuando debe ejecutarla un agente distinto de '
                    'quienes produjeron sus dependencias.',
              ),
              'executor': Schema.string(
                description:
                    'newSession, resumeParent, providerSubagent o manualApproval.',
              ),
              'parent_capability_id': Schema.string(
                description:
                    'Nodo padre obligatorio para resumeParent y providerSubagent.',
              ),
              'max_agentic_turns': Schema.int(
                description: 'Presupuesto de turnos, de 0 a 20.',
              ),
              'approval_required': Schema.bool(
                description:
                    'True si el motor debe pedir la aprobación del usuario '
                    'antes de correr este nodo (p. ej. publicar).',
              ),
              'read_only': Schema.bool(
                description:
                    'True para planificación y auditorías sin escritura.',
              ),
              'output_contract': Schema.string(
                description: 'Contrato de salida, por ejemplo audit-feedback.',
              ),
            },
            required: ['id', 'title', 'instruction', 'role', 'activation'],
          ),
          description:
              'Capacidades completas. Reemplazan las actuales sin imponer orden lineal.',
        ),
        'new_name': Schema.string(description: 'Renombrar (opcional).'),
      },
      required: ['name'],
    ),
  ),
  Tool(
    name: 'unassign_from_agent',
    description:
        'SACA skills, reglas, hooks, tools, MCPs o conocimiento de un agente. '
        'create_or_update_agent solo SUMA, así que esta es la única forma '
        'de quitar algo mal asignado sin borrar el agente entero.',
    inputSchema: ObjectSchema(
      properties: {
        'handle': Schema.string(description: 'Handle del agente, sin @.'),
        'skill_names': Schema.list(items: Schema.string()),
        'rule_names': Schema.list(items: Schema.string()),
        'hook_names': Schema.list(items: Schema.string()),
        'tool_names': Schema.list(items: Schema.string()),
        'mcp_server_names': Schema.list(items: Schema.string()),
        'knowledge_base_names': Schema.list(items: Schema.string()),
      },
      required: ['handle'],
    ),
  ),
  Tool(
    name: 'update_project',
    description:
        'Actualiza un proyecto existente: propósito, directorio de '
        'trabajo, miembros, workflows disponibles, reglas propias, si lo '
        'mantiene el usuario y cuál es el workflow ACTIVO. Solo cambia lo '
        'que mandes; los miembros y workflows que envíes REEMPLAZAN a los '
        'actuales.',
    inputSchema: ObjectSchema(
      properties: {
        'name': Schema.string(description: 'Nombre del proyecto.'),
        'purpose': Schema.string(description: 'Propósito nuevo.'),
        'working_directory': Schema.string(
          description: 'Ruta absoluta del directorio de trabajo.',
        ),
        'agent_handles': Schema.list(
          items: Schema.string(),
          description: 'Miembros (handles sin @). Reemplazan a los actuales.',
        ),
        'workflow_names': Schema.list(
          items: Schema.string(),
          description: 'Workflows disponibles. Reemplazan a los actuales.',
        ),
        'rule_names': Schema.list(
          items: Schema.string(),
          description: 'Reglas del proyecto. Reemplazan a las actuales.',
        ),
        'hook_names': Schema.list(
          items: Schema.string(),
          description: 'Hooks del proyecto. Reemplazan a los actuales.',
        ),
        'knowledge_base_names': Schema.list(
          items: Schema.string(),
          description:
              'Bases de saber que ve este proyecto. Reemplazan a las '
              'actuales.',
        ),
        'maintained': Schema.bool(
          description:
              'Si el usuario mantiene este proyecto. En false queda de SOLO '
              'LECTURA: sus sesiones no reciben las tools que escriben y no '
              'toma requerimientos de otros proyectos. Omitilo para dejarlo '
              'como está.',
        ),
        'active_workflow': Schema.string(
          description:
              'Nombre del workflow que queda ACTIVO (tiene que estar entre '
              'los disponibles).',
        ),
        'member_engines': Schema.list(
          items: ObjectSchema(
            properties: {
              'handle': Schema.string(),
              'provider': Schema.string(
                description: 'claude, codex, openrouter o deepseek.',
              ),
              'model': Schema.string(
                description: 'ID exacto; vacío hereda del perfil.',
              ),
              'effort': Schema.string(
                description: 'Esfuerzo; vacío hereda del perfil.',
              ),
              'clear': Schema.bool(
                description: 'True elimina el override completo.',
              ),
            },
            required: ['handle'],
          ),
          description: 'Overrides de motor por miembro para este proyecto.',
        ),
        'node_assignments': Schema.list(
          items: ObjectSchema(
            properties: {
              'workflow': Schema.string(),
              'node_id': Schema.string(),
              'handle': Schema.string(
                description: 'Vacío elimina el override.',
              ),
            },
            required: ['workflow', 'node_id'],
          ),
          description:
              'Overrides concretos workflow/capacidad/agente del proyecto.',
        ),
        'new_name': Schema.string(description: 'Renombrar (opcional).'),
      },
      required: ['name'],
    ),
  ),
  Tool(
    name: 'open_project_session',
    description:
        'Abre una SESIÓN en un proyecto y le manda el prompt inicial al '
        'canal: sus miembros empiezan a trabajar según el workflow activo. '
        'La sesión corre sola, no bloquea tu respuesta.',
    inputSchema: ObjectSchema(
      properties: {
        'project': Schema.string(description: 'Nombre del proyecto.'),
        'prompt': Schema.string(
          description: 'Qué tiene que hacer el proyecto, en detalle.',
        ),
      },
      required: ['project', 'prompt'],
    ),
  ),
  Tool(
    name: 'list_project_sessions',
    description:
        'Las SESIONES de un proyecto: id, título, cuándo se abrió, si está '
        'corriendo, cuántos mensajes tiene y con qué workflow. Es el índice '
        'para después leer un hilo con read_session_thread.',
    inputSchema: ObjectSchema(
      properties: {
        'project': Schema.string(description: 'Nombre del proyecto.'),
      },
      required: ['project'],
    ),
  ),
  Tool(
    name: 'read_session_thread',
    description:
        'El HILO de una sesión: quién escribió cada mensaje, en qué nodo de '
        'resolución, a qué hora y qué dijo. Cada línea trae su REFERENCIA '
        '(keel://message/...), que es lo que se le pasa a '
        'resolve_message_reference y a reply_in_session. Sin `session` lee la '
        'sesión activa del proyecto.',
    inputSchema: ObjectSchema(
      properties: {
        'project': Schema.string(description: 'Nombre del proyecto.'),
        'session': Schema.string(
          description: 'Id o título exacto de la sesión. Vacío = la activa.',
        ),
        'limit': Schema.int(
          description: 'Cuántos mensajes del final traer. Por defecto 40.',
        ),
      },
      required: ['project'],
    ),
  ),
  Tool(
    name: 'resolve_message_reference',
    description:
        'Resuelve una referencia de mensaje que el usuario te pegó '
        '(keel://message/...) y te devuelve ESE mensaje entero junto con su '
        'contexto: proyecto, sesión, quién lo escribió, en qué nodo, y los '
        'mensajes de antes y de después. Usala apenas veas una referencia: '
        'sin el contexto no podés explicar a qué se refiere, solo repetirlo.',
    inputSchema: ObjectSchema(
      properties: {
        'reference': Schema.string(
          description:
              'La referencia tal como te la pegó el usuario. Acepta el token '
              'pelado o adentro de una oración.',
        ),
      },
      required: ['reference'],
    ),
  ),
  Tool(
    name: 'reply_in_session',
    description:
        'Manda una respuesta AL CANAL de la sesión de la que salió esa '
        'referencia, citando el mensaje original y dirigida al miembro que '
        'preguntó. El mensaje sale de verdad: si la sesión está corriendo '
        'entra como el turno siguiente. En el hilo queda marcado como puesto '
        'por vos en nombre del usuario. LLAMALA SOLO cuando el usuario ya '
        'decidió y te pidió responder — nunca por tu cuenta, y nunca antes de '
        'haberle explicado de qué se trata.',
    inputSchema: ObjectSchema(
      properties: {
        'reference': Schema.string(
          description: 'La referencia del mensaje que se está contestando.',
        ),
        'text': Schema.string(
          description:
              'La respuesta, tal como el usuario la decidió. Es lo que va a '
              'leer el miembro: escribila para él, no para el usuario.',
        ),
      },
      required: ['reference', 'text'],
    ),
  ),
  Tool(
    name: 'inspect_session',
    description:
        'El ESTADO de una sesión de proyecto para opinar sobre ella: resumen '
        'del caso, tabla de nodos (id, título, estado, dueño, intentos, '
        'costo, último cierre), decisiones pendientes con su id, hallazgos '
        'abiertos y, con `full`, los últimos mensajes sin recortar y los '
        'subagentes con su resultado. Usala PRIMERO cuando el usuario te pide '
        'revisar una sesión; nunca por tu cuenta.',
    inputSchema: ObjectSchema(
      properties: {
        'project': Schema.string(description: 'Nombre del proyecto.'),
        'session': Schema.string(
          description: 'Id o título exacto de la sesión. Vacío = la activa.',
        ),
        'full': Schema.bool(
          description:
              'True para incluir los últimos 20 mensajes completos y los '
              'subagentes. Por defecto false.',
        ),
      },
      required: ['project'],
    ),
  ),
  Tool(
    name: 'intervene',
    description:
        'Manda una instrucción AL CANAL de una sesión, en nombre del '
        'usuario. Si la sesión está corriendo interrumpe el turno actual (el '
        'nodo retoma después); si no, abre el turno siguiente. LLAMALA SOLO '
        'cuando el usuario te pidió intervenir y con una instrucción '
        'concreta que salga de lo que viste en inspect_session.',
    inputSchema: ObjectSchema(
      properties: {
        'project': Schema.string(description: 'Nombre del proyecto.'),
        'session': Schema.string(
          description: 'Id o título exacto de la sesión. Vacío = la activa.',
        ),
        'text': Schema.string(
          description: 'La instrucción, escrita para el agente que la lee.',
        ),
      },
      required: ['project', 'text'],
    ),
  ),
  Tool(
    name: 'answer_decision',
    description:
        'Contesta una decisión pendiente de una sesión (una pregunta, un '
        'permiso o una aprobación que un agente le pidió al usuario), con el '
        'id que devuelve inspect_session. SOLO cuando el usuario te dijo qué '
        'contestar: vos no decidís por él.',
    inputSchema: ObjectSchema(
      properties: {
        'project': Schema.string(description: 'Nombre del proyecto.'),
        'session': Schema.string(description: 'Id o título de la sesión.'),
        'decision_id': Schema.string(description: 'Id de la decisión.'),
        'answer': Schema.string(
          description: 'La respuesta, para una pregunta.',
        ),
        'approve': Schema.bool(
          description: 'True/false para un permiso o una aprobación.',
        ),
        'scope': Schema.string(
          description:
              'Alcance de un permiso concedido: once | session | profile | '
              'app. Por defecto once.',
        ),
      },
      required: ['project', 'decision_id'],
    ),
  ),
  Tool(
    name: 'lint_workflow',
    description:
        'Revisa un conjunto de capacidades ANTES de crear o actualizar un '
        'workflow: cantidad de nodos, aprobaciones manuales opcionales que '
        'nunca disparan, auditorías sin contrato de salida, nodos duplicados, '
        'nodos sin tope. Devuelve errores (bloquean) y avisos. Mismo formato '
        'de `capabilities` que create_workflow.',
    inputSchema: ObjectSchema(
      properties: {
        'capabilities': Schema.list(
          items: ObjectSchema(properties: {}),
          description: 'Las capacidades, como en create_workflow.',
        ),
      },
      required: ['capabilities'],
    ),
  ),
  Tool(
    name: 'describe_system',
    description:
        'Estado actual del sistema: qué está configurado (repos de catálogo '
        'y conocimiento), qué secrets faltan cargar, qué MCPs no van a '
        'levantar por falta de clave, referencias inválidas del catálogo, '
        'qué agentes tienen conversación abierta y qué proyectos tienen '
        'sesiones corriendo. Usalo cuando el '
        'usuario pregunte "cómo está esto" o antes de diagnosticar algo que '
        'no funciona.',
    inputSchema: ObjectSchema(properties: {}),
  ),
  Tool(
    name: 'list_secret_names',
    description:
        'Lista los NOMBRES de los secrets registrados y si están pendientes '
        'de valor. Los valores jamás se exponen.',
    inputSchema: ObjectSchema(properties: {}),
  ),
  Tool(
    name: 'create_or_update_agent',
    description:
        'Crea un agente si el handle no existe. Si ya existe, actualiza de '
        'forma ADITIVA: skills, reglas, hooks, tools, MCPs y conocimiento '
        'se fusionan con lo que el '
        'agente ya tenía (nunca se reemplazan), y role/instructions solo se '
        'pisan si vienen en la llamada. El handle "keelai" está reservado y '
        'se rechaza.',
    inputSchema: ObjectSchema(
      properties: {
        'handle': Schema.string(
          description: 'Handle único del agente, minúsculas, sin espacios.',
        ),
        'role': Schema.string(description: 'Rol corto del agente.'),
        'purpose': Schema.string(description: 'Para qué sirve este agente.'),
        'instructions': Schema.string(
          description: 'Instrucciones de sistema del agente.',
        ),
        'skill_names': Schema.list(
          items: Schema.string(),
          description: 'Skills a asignarle.',
        ),
        'rule_names': Schema.list(
          items: Schema.string(),
          description: 'Reglas a asignarle.',
        ),
        'tool_names': Schema.list(
          items: Schema.string(),
          description: 'Tools ejecutables a asignarle.',
        ),
        'mcp_server_names': Schema.list(
          items: Schema.string(),
          description: 'MCPs externos (registrados) a asignarle.',
        ),
        'hook_names': Schema.list(
          items: Schema.string(),
          description: 'Hooks registrados que protegen sus turnos.',
        ),
        'knowledge_base_names': Schema.list(
          items: Schema.string(),
          description:
              'Bases de saber que este agente lleva consigo a donde vaya, '
              'incluido el chat 1:1 — el caso ORÁCULO, para un agente que ES '
              'de ese dominio. El saber de un proyecto se pone en su '
              'proyecto, no acá.',
        ),
        'provider': Schema.string(
          description:
              'Proveedor: "claude", "codex", "openrouter" o "deepseek". '
              'Omitir conserva el actual en una actualización.',
        ),
        'model': Schema.string(
          description:
              'ID exacto del modelo del proveedor. Al cambiar proveedor y '
              'omitirlo, se normaliza al default del proveedor nuevo.',
        ),
        'effort': Schema.string(
          description:
              'Esfuerzo de razonamiento cuando el proveedor lo admita.',
        ),
        'system_builder': Schema.bool(
          description:
              'true para que este agente pueda administrar el sistema '
              '(recibe estas mismas tools de creación en sus chats 1:1). '
              'Solo cuando el usuario pidió explícitamente un agente '
              'constructor. Si no se manda, en un update se conserva lo que '
              'ya tenía.',
        ),
      },
      required: ['handle'],
    ),
  ),
  Tool(
    name: 'create_workflow',
    description:
        'Crea un workflow adaptativo completo. El motor construye un grafo '
        'mínimo de nodos según el tipo, en vez de ejecutar una cadena de '
        'pasos.',
    inputSchema: ObjectSchema(
      properties: {
        'name': Schema.string(description: 'Nombre único del workflow.'),
        'when_to_apply': Schema.string(
          description:
              'En qué situación se aplica este workflow. Es el texto que se '
              'lee al elegir con cuál corre una sesión: escribilo para que '
              'sirva para decidir.',
        ),
        'skills': Schema.list(
          items: Schema.string(),
          description: 'Skills obligatorias del preflight, por nombre.',
        ),
        'kind': Schema.string(
          description: '"general", "bug", "migration" o "roadmap".',
        ),
        'resolution_role': Schema.string(
          description: 'Rol responsable; vacío permite asignación automática.',
        ),
        'rule_names': Schema.list(
          items: Schema.string(),
          description: 'Reglas obligatorias del preflight, por nombre.',
        ),
        'knowledge_base_names': Schema.list(
          items: Schema.string(),
          description:
              'Bases de conocimiento obligatorias del preflight, por nombre.',
        ),
        'quality_gates': Schema.list(
          items: Schema.string(),
          description:
              'Gates: analysis, focusedTests, compatibility, regression.',
        ),
        'max_replans': Schema.int(
          description: 'Máximo de reformulaciones, de 0 a 2.',
        ),
        'max_subagents': Schema.int(
          description:
              'Máximo de subagentes de lectura/verificación que cada NODO '
              'puede abrir en paralelo, de 0 a 6. El cupo es por nodo, no por '
              'corrida: un nodo no le consume el presupuesto al siguiente.',
        ),
        'max_review_cycles': Schema.int(
          description: 'Máximo total de ciclos auditoría/corrección, de 1 a 4.',
        ),
        'builds_roadmap': Schema.bool(
          description:
              'True solo para un workflow que construye y valida TASKS.',
        ),
        'capabilities': Schema.list(
          items: ObjectSchema(
            properties: {
              'id': Schema.string(description: 'ID estable del nodo.'),
              'title': Schema.string(
                description: 'Título visible en el panel.',
              ),
              'instruction': Schema.string(
                description: 'Contrato del trabajo.',
              ),
              'role': Schema.string(description: 'Rol por defecto.'),
              'dependencies': Schema.list(items: Schema.string()),
              'activation': Schema.string(
                description: '"required" u "optional".',
              ),
              'independent': Schema.bool(
                description:
                    'True cuando debe ejecutarla un agente distinto de '
                    'quienes produjeron sus dependencias.',
              ),
              'executor': Schema.string(
                description:
                    'newSession, resumeParent, providerSubagent o manualApproval.',
              ),
              'parent_capability_id': Schema.string(
                description:
                    'Nodo padre obligatorio para resumeParent y providerSubagent.',
              ),
              'max_agentic_turns': Schema.int(
                description: 'Presupuesto de turnos, de 0 a 20.',
              ),
              'approval_required': Schema.bool(
                description:
                    'True si el motor debe pedir la aprobación del usuario '
                    'antes de correr este nodo (p. ej. publicar).',
              ),
              'read_only': Schema.bool(
                description:
                    'True para planificación y auditorías sin escritura.',
              ),
              'output_contract': Schema.string(
                description: 'Contrato de salida, por ejemplo audit-feedback.',
              ),
            },
            required: ['id', 'title', 'instruction', 'role', 'activation'],
          ),
          description:
              'Capacidades adaptativas; solo required entra al grafo inicial.',
        ),
      },
      required: ['name'],
    ),
  ),
  Tool(
    name: 'create_project',
    description:
        'Crea un proyecto: el contexto de un proyecto (un repo/producto) '
        'con su directorio de trabajo, sus miembros, sus workflows '
        'disponibles y sus reglas. Resuelve handles de agente y nombres de '
        'workflow a sus ids reales, y reporta qué referencias no se pudieron '
        'resolver.',
    inputSchema: ObjectSchema(
      properties: {
        'name': Schema.string(description: 'Nombre único del proyecto.'),
        'purpose': Schema.string(description: 'Propósito del proyecto.'),
        'working_directory': Schema.string(
          description: 'Directorio de trabajo absoluto del proyecto.',
        ),
        'agent_handles': Schema.list(
          items: Schema.string(),
          description: 'Handles de los agentes miembro.',
        ),
        'workflow_names': Schema.list(
          items: Schema.string(),
          description: 'Nombres de los workflows a asociar.',
        ),
        'rule_names': Schema.list(
          items: Schema.string(),
          description: 'Nombres de las reglas a aplicar.',
        ),
        'hook_names': Schema.list(
          items: Schema.string(),
          description: 'Hooks registrados a aplicar en el proyecto.',
        ),
        'knowledge_base_names': Schema.list(
          items: Schema.string(),
          description:
              'Bases de saber del proyecto. Sus miembros reciben el mapa de '
              'cada una y las consultan solos; ningún otro proyecto las ve.',
        ),
        'maintained': Schema.bool(
          description:
              'False si es externo y debe quedar en modo de solo lectura.',
        ),
      },
      required: ['name', 'purpose', 'working_directory'],
    ),
  ),
  Tool(
    name: 'create_knowledge_base',
    description:
        'Registra una base de saber: un cuerpo de documentación con nombre '
        'propio (NUI, CONNECT) que después se le asigna a un proyecto con '
        'knowledge_base_names. source "local" apunta a una carpeta del disco '
        '(se crea si no existe, y es donde ESCRIBÍS los documentos con tus '
        'herramientas de archivo); source "git" clona un repo a un espejo '
        'que administra la app, y ahí NO se escribe: el contenido se cambia '
        'en el repo. Idempotente no es: si el nombre ya existe, falla — para '
        'cambiarla usá update_knowledge_base.',
    inputSchema: ObjectSchema(
      properties: {
        'name': Schema.string(
          description:
              'Nombre único. Letras, números, "-" y "_"; sin espacios.',
        ),
        'description': Schema.string(
          description:
              'Una línea: qué contesta esta base. Es lo primero que lee un '
              'agente para decidir si buscar acá.',
        ),
        'source': Schema.string(description: '"local" o "git".'),
        'local_path': Schema.string(
          description: 'Ruta absoluta de la carpeta (source "local").',
        ),
        'git_url': Schema.string(description: 'URL del repo (source "git").'),
        'git_branch': Schema.string(description: 'Rama (opcional).'),
      },
      required: ['name', 'description', 'source'],
    ),
  ),
  Tool(
    name: 'update_knowledge_base',
    description:
        'Cambia el nombre, la descripción o la fuente de una base de saber '
        'existente. Solo lo que mandes; el resto queda como estaba.',
    inputSchema: ObjectSchema(
      properties: {
        'name': Schema.string(description: 'Nombre actual de la base.'),
        'new_name': Schema.string(description: 'Renombrar (opcional).'),
        'description': Schema.string(description: 'Descripción nueva.'),
        'source': Schema.string(description: '"local" o "git".'),
        'local_path': Schema.string(description: 'Carpeta (source "local").'),
        'git_url': Schema.string(description: 'URL del repo (source "git").'),
        'git_branch': Schema.string(description: 'Rama.'),
      },
      required: ['name'],
    ),
  ),
  Tool(
    name: 'delete_knowledge_base',
    description:
        'Da de baja una base de saber del catálogo. NO borra sus documentos '
        'del disco: saca el registro y deja de llegarles a los agentes.',
    inputSchema: ObjectSchema(
      properties: {'name': Schema.string(description: 'Nombre de la base.')},
      required: ['name'],
    ),
  ),
  Tool(
    name: 'delete_skill',
    description: 'Elimina una skill por nombre.',
    inputSchema: ObjectSchema(
      properties: {
        'name': Schema.string(description: 'Nombre de la skill a eliminar.'),
      },
      required: ['name'],
    ),
  ),
  Tool(
    name: 'delete_rule',
    description: 'Elimina una regla por nombre.',
    inputSchema: ObjectSchema(
      properties: {
        'name': Schema.string(description: 'Nombre de la regla a eliminar.'),
      },
      required: ['name'],
    ),
  ),
  Tool(
    name: 'delete_tool',
    description: 'Elimina una tool ejecutable por nombre.',
    inputSchema: ObjectSchema(
      properties: {
        'name': Schema.string(description: 'Nombre de la tool a eliminar.'),
      },
      required: ['name'],
    ),
  ),
  Tool(
    name: 'delete_agent',
    description:
        'Elimina un agente registrado por handle. El handle "keelai" está '
        'reservado y no se puede eliminar.',
    inputSchema: ObjectSchema(
      properties: {
        'handle': Schema.string(description: 'Handle del agente a eliminar.'),
      },
      required: ['handle'],
    ),
  ),
  Tool(
    name: 'delete_workflow',
    description:
        'Elimina un workflow por nombre y limpia automáticamente sus '
        'asignaciones, default, overrides y referencias de sesión en todos '
        'los proyectos.',
    inputSchema: ObjectSchema(
      properties: {
        'name': Schema.string(description: 'Nombre del workflow a eliminar.'),
      },
      required: ['name'],
    ),
  ),
  Tool(
    name: 'delete_project',
    description:
        'Elimina un proyecto por nombre, junto con sus sesiones en curso.',
    inputSchema: ObjectSchema(
      properties: {
        'name': Schema.string(description: 'Nombre del proyecto a eliminar.'),
      },
      required: ['name'],
    ),
  ),
]);

const _catalogMutationToolNames = {
  'create_skill',
  'update_skill',
  'delete_skill',
  'create_rule',
  'update_rule',
  'delete_rule',
  'create_tool',
  'update_tool',
  'delete_tool',
  'create_hook',
  'set_hook_enabled',
  'delete_hook',
  'create_or_update_agent',
  'unassign_from_agent',
  'delete_agent',
  'create_workflow',
  'update_workflow',
  'delete_workflow',
  'create_project',
  'update_project',
  'delete_project',
  'register_mcp_server',
  'install_mcp_integration',
  'delete_mcp_server',
  'create_knowledge_base',
  'update_knowledge_base',
  'delete_knowledge_base',
  'request_secret',
  'restore_system',
};

/// The fields stay optional for the unchanged unlocked path. They are part
/// of every write schema so a model can provide the required explanation
/// when the target turns out to be protected.
List<Tool> _withCatalogChangeParameters(List<Tool> tools) => [
  for (final tool in tools)
    if (!_catalogMutationToolNames.contains(tool.name))
      tool
    else
      Tool(
        name: tool.name,
        description:
            '${tool.description}\n\nSi el elemento está bloqueado, incluí '
            'change_intent y change_reason; sin ambos no se escribe. Y con '
            'los dos, esta llamada QUEDA ESPERANDO a que la persona apruebe '
            'o rechace: puede tardar minutos y eso es normal. No la '
            'reintentes, no la canceles y no busques otro camino para el '
            'mismo cambio mientras esperás — cuando conteste, la tool te '
            'dice si escribió o no.',
        inputSchema: ObjectSchema(
          properties: {
            ...?tool.inputSchema.properties,
            'change_intent': Schema.string(
              description: 'Qué cambio querés hacer, si está bloqueado.',
            ),
            'change_reason': Schema.string(
              description: 'Por qué el cambio es necesario, si está bloqueado.',
            ),
          },
          required: tool.inputSchema.required,
        ),
      ),
];
