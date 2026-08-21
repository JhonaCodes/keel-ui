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
    name: 'create_or_update_agent',
    description:
        'Crea un agente si el handle no existe. Si ya existe, actualiza de '
        'forma ADITIVA: skills y reglas se fusionan con lo que el agente ya '
        'tenía (nunca se reemplazan), y role/instructions solo se pisan si '
        'vienen en la llamada. El handle "keelai" está reservado y se '
        'rechaza.',
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
