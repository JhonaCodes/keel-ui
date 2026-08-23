library;

// Los targets viven en la carpeta de su proveedor, no acá adentro: este
// barrel es el contrato compartido y no puede depender de ningún runner
// concreto (eso lo hace `llm_dispatcher.dart`, que sí importa cada
// `*_cli_runner.dart` y no al revés — ver arquitectura-llm-providers).
import 'codex/codex_target.dart';
import 'claude/claude_target.dart';

export 'codex/codex_target.dart';
export 'claude/claude_target.dart';

part 'src/llm_provider.dart';
part 'src/llm_runner.dart';
part 'src/llm_turn_spec.dart';
