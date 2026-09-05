/// Todos los prompts de sistema de la app, en un solo lugar.
///
/// Antes vivían desperdigados: el de Keel AI en `modules/assistant/model/`,
/// el del formato del roadmap en `modules/projects/model/`, las secciones
/// del turno adentro de un ViewModel de 4200 líneas, y las pistas de CLI en
/// `core/services/`. Cambiar una regla de conducta obligaba a recordar en
/// cuál de los cuatro estaba, y dos prompts que se contradicen entre sí
/// —pasó con ENTREGA y el MCP de GitHub— no se notaban hasta verlos correr.
///
/// Acá hay **texto**, no lógica: quién arma cada turno y en qué orden apila
/// las secciones sigue siendo del ViewModel que corre el turno. Esta
/// biblioteca es el corpus, y cada archivo documenta en español qué dice su
/// prompt, por qué se escribió y quién lo consume.
///
/// Lo que a propósito NO está acá: las ~30 descripciones de tools de
/// `assistant_mcp/src/tool_definitions.dart`. Son esquemas MCP —contrato de
/// una tool, validado por su servidor— y no instrucciones de conducta;
/// mudarlas sería ruido sin lector nuevo.
library;

import 'package:keel_ui/src/integrations/git_worktree/git_worktree.dart';
import 'package:keel_ui/src/modules/agents/model/agent_provider.dart';
import 'package:keel_ui/src/modules/projects/model/resolution_case.dart';
import 'package:keel_ui/src/modules/projects/model/session.dart';
import 'package:keel_ui/src/modules/projects/model/session_plan_item.dart';
import 'package:keel_ui/src/modules/projects/model/work_node.dart';
import 'package:keel_ui/src/modules/workflows/model/workflow.dart';
import 'package:keel_ui/src/modules/mcp_servers/model/mcp_server_config.dart';

part 'src/keelai_system_map.dart';
part 'src/keelai_prompt.dart';
part 'src/roadmap_format_prompt.dart';
part 'src/cli_hints_prompt.dart';
part 'src/turn_discipline_prompt.dart';
part 'src/identity_prompt.dart';
part 'src/delivery_prompt.dart';
part 'src/subagent_policy_prompt.dart';
part 'src/plan_section_prompt.dart';
part 'src/adaptive_node_prompt.dart';
part 'src/outcome_protocol_prompt.dart';
part 'src/consult_prompt.dart';
part 'src/known_roots_prompt.dart';
part 'src/github_mcp_prompt.dart';
part 'src/plan_mode_prompt.dart';
part 'src/mcp_server_instructions.dart';
