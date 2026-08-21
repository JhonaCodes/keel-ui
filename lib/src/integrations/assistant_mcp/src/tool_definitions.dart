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
        'cargar el usuario desde la pantalla de Secrets — nunca lo pidas por '
        'chat ni lo aceptes si te lo pegan (deciles que lo carguen en la '
        'pantalla). Idempotente por nombre.',
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
    name: 'export_catalog',
    description:
        'Exporta TODO el catálogo (skills, reglas, tools, workflows, MCPs, '
        'agentes, estaciones) al repo git configurado en Configuración → '
        'Sincronización, y lo pushea. Sin secrets ni rutas de trabajo.',
    inputSchema: ObjectSchema(properties: {}),
  ),
  Tool(
    name: 'refresh_catalog',
    description:
        'Trae el catálogo del repo git configurado y lo fusiona por nombre '
        '(crea lo que falta, actualiza lo existente). Las estaciones nuevas '
        'quedan sin carpeta de trabajo hasta que el usuario la elija en la '
        'UI.',
    inputSchema: ObjectSchema(properties: {}),
  ),
  Tool(
    name: 'update_knowledge',
    description:
        'Trae (git pull) la documentación del repo de conocimiento '
        'configurado por el usuario y reindexa la sección Conocimiento.',
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
        'Idempotente por nombre.',
    inputSchema: ObjectSchema(
      properties: {
        'name': Schema.string(description: 'Nombre único del workflow.'),
        'when_to_apply': Schema.string(
          description: 'En qué situación se aplica este workflow.',
        ),
        'steps': Schema.list(
          description: 'Pasos del workflow, en el orden en que se ejecutan.',
          items: Schema.object(
            properties: {
              'title': Schema.string(description: 'Título corto del paso.'),
              'role': Schema.string(
                description:
                    'Rol a buscar entre los miembros de la estación, no un '
                    'agente específico.',
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
    name: 'create_station',
    description:
        'Crea una estación, resolviendo handles de agente y nombres de '
        'workflow a sus ids reales. Reporta qué referencias no se pudieron '
        'resolver.',
    inputSchema: ObjectSchema(
      properties: {
        'name': Schema.string(description: 'Nombre único de la estación.'),
        'purpose': Schema.string(description: 'Propósito de la estación.'),
        'working_directory': Schema.string(
          description: 'Directorio de trabajo absoluto de la estación.',
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
      },
      required: ['name', 'purpose', 'working_directory'],
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
        'handle': Schema.string(
          description: 'Handle del agente a eliminar.',
        ),
      },
      required: ['handle'],
    ),
  ),
  Tool(
    name: 'delete_workflow',
    description: 'Elimina un workflow por nombre.',
    inputSchema: ObjectSchema(
      properties: {
        'name': Schema.string(
          description: 'Nombre del workflow a eliminar.',
        ),
      },
      required: ['name'],
    ),
  ),
  Tool(
    name: 'delete_station',
    description:
        'Elimina una estación por nombre, junto con sus tareas en curso.',
    inputSchema: ObjectSchema(
      properties: {
        'name': Schema.string(
          description: 'Nombre de la estación a eliminar.',
        ),
      },
      required: ['name'],
    ),
  ),
];
