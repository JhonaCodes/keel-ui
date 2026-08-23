part of '../assistant_mcp_server.dart';

/// Same five actions the fenced-block mechanism already knows how to run —
/// see `assistant_action_executor.dart`. Deliberately no new scope here:
/// changing transport and scope in the same step would be hard to diagnose
/// if something broke.
final List<Tool> keelAiTools = [
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
        'keel-backup.zip de la carpeta del vault. Con push=true además lo '
        'commitea y lo sube al repo del vault. De los secrets viajan solo '
        'los nombres, nunca los valores; los hilos de chat no viajan.',
    inputSchema: ObjectSchema(
      properties: {
        'push': Schema.bool(
          description:
              'Si además de escribir el zip hay que commitear y pushear el '
              'vault. Por defecto false.',
        ),
      },
    ),
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
        'agentes, workflows, proyectos y MCPs registrados, con su nombre y '
        'para qué sirve cada uno. USALA ANTES de asignarle cualquier cosa a '
        'un agente o a un proyecto: los nombres se referencian tal cual, y '
        'un nombre inventado se descarta. Sin `kind` devuelve todo el '
        'catálogo.',
    inputSchema: ObjectSchema(
      properties: {
        'kind': Schema.string(
          description:
              'Qué listar: skills, rules, tools, agents, workflows, '
              'projects, mcp_servers, knowledge_bases, o all (default).',
        ),
      },
    ),
  ),
  Tool(
    name: 'get_item',
    description:
        'Devuelve el CONTENIDO COMPLETO de una cosa registrada: el texto '
        'entero de una skill o regla, el código de una tool, los pasos de '
        'un workflow, la configuración de un agente o de un proyecto. '
        'Usala ANTES de actualizar cualquier cosa: los update reemplazan el '
        'contenido, así que sin leerlo primero pisás lo que había.',
    inputSchema: ObjectSchema(
      properties: {
        'kind': Schema.string(
          description:
              'Tipo: skill, rule, tool, agent, workflow, project, '
              'mcp_server o knowledge_base.',
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
        'Actualiza un workflow existente: cuándo aplica y/o sus pasos. Si '
        'mandás steps, reemplazan a TODOS los actuales.',
    inputSchema: ObjectSchema(
      properties: {
        'name': Schema.string(description: 'Nombre del workflow.'),
        'when_to_apply': Schema.string(
          description: 'Cuándo se usa este workflow.',
        ),
        'steps': Schema.list(
          items: Schema.object(
            properties: {
              'title': Schema.string(),
              'role': Schema.string(),
              'instruction': Schema.string(),
            },
          ),
          description: 'Pasos nuevos, en orden. Reemplazan a los actuales.',
        ),
        'skills': Schema.list(
          items: Schema.string(),
          description:
              'Skills que este workflow le suma a TODOS sus turnos, por '
              'nombre. Reemplazan a las actuales. Son distintas de las del '
              'agente: las del agente son quién es, estas son qué está '
              'haciendo.',
        ),
        'new_name': Schema.string(description: 'Renombrar (opcional).'),
      },
      required: ['name'],
    ),
  ),
  Tool(
    name: 'unassign_from_agent',
    description:
        'SACA skills, reglas, tools o MCPs de un agente. '
        'create_or_update_agent solo SUMA, así que esta es la única forma '
        'de quitar algo mal asignado sin borrar el agente entero.',
    inputSchema: ObjectSchema(
      properties: {
        'handle': Schema.string(description: 'Handle del agente, sin @.'),
        'skill_names': Schema.list(items: Schema.string()),
        'rule_names': Schema.list(items: Schema.string()),
        'tool_names': Schema.list(items: Schema.string()),
        'mcp_server_names': Schema.list(items: Schema.string()),
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
    name: 'describe_system',
    description:
        'Estado actual del sistema: qué está configurado (repos de catálogo '
        'y conocimiento), qué secrets faltan cargar, qué MCPs no van a '
        'levantar por falta de clave, qué agentes tienen conversación '
        'abierta y qué proyectos tienen sesiones corriendo. Usalo cuando el '
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
        'forma ADITIVA: skills, reglas y tools se fusionan con lo que el '
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
              'CLI que corre al agente: "claude" (default) o "codex". '
              'Codex no recibe tools/MCPs/esfuerzo.',
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
        'Crea un workflow (nombre, cuándo se aplica, pasos ordenados). '
        'Idempotente por nombre. Cada paso nombra el ROL o el HANDLE de un '
        'agente ya registrado: listá los agentes ANTES de escribir los '
        'pasos. Un proyecto puede tener varios y cada SESIÓN elige con cuál '
        'corre, así que conviene uno por clase de trabajo en vez de uno '
        'gigante que sirva para todo.',
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
          description:
              'Skills que este workflow le suma a TODOS sus turnos, por '
              'nombre. Son distintas de las del agente: las del agente son '
              'quién es, estas son qué está haciendo.',
        ),
        'steps': Schema.list(
          description: 'Pasos del workflow, en el orden en que se ejecutan.',
          items: Schema.object(
            properties: {
              'title': Schema.string(description: 'Título corto del paso.'),
              'role': Schema.string(
                description:
                    'A quién le toca el paso. Se busca entre los miembros de '
                    'el proyecto: primero por su ROL, y si nadie lo tiene, '
                    'por su HANDLE. Tiene que coincidir EXACTO con uno de '
                    'los dos de un agente ya registrado — corré '
                    'list_catalog(kind: "agents") y copiá el valor, no lo '
                    'redactes. Un rol que no le corresponde a nadie deja el '
                    'paso sin dueño y el proyecto lo muestra como "sin '
                    'agente para X".',
              ),
              'instruction': Schema.string(
                description: 'Instrucción del paso.',
              ),
            },
            required: ['title', 'role', 'instruction'],
          ),
        ),
      },
      required: ['name', 'steps'],
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
        'knowledge_base_names': Schema.list(
          items: Schema.string(),
          description:
              'Bases de saber del proyecto. Sus miembros reciben el mapa de '
              'cada una y las consultan solos; ningún otro proyecto las ve.',
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
    description: 'Elimina un workflow por nombre.',
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
];
