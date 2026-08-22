/// Cómo un hook del catálogo se convierte en configuración que el CLI
/// entiende.
///
/// Es la mitad pura de la feature: entran hooks, tools y valores de
/// secrets; salen Strings. No toca el disco ni lanza procesos — eso lo hace
/// quien la llama, en el mismo directorio temporal 0700 donde ya viaja el
/// `mcp.json`. Separado así porque es lo único de todo esto que se puede
/// probar sin levantar la app.
///
/// Los dos CLIs resultaron tener la MISMA forma de configuración (evento →
/// matcher → comandos, `exit 2` bloquea), así que el render es un cambio de
/// sintaxis —JSON para claude, TOML para codex— y no dos modelos distintos.
library;

import 'dart:convert';

import 'package:keel_ui/src/core/services/cli_turn_workspace.dart';
import 'package:keel_ui/src/modules/agent_profiles/model/agent_profile.dart';
import 'package:keel_ui/src/modules/hooks/model/hook.dart';
import 'package:keel_ui/src/modules/hooks/model/hook_event.dart';
import 'package:keel_ui/src/modules/projects/model/project.dart';
import 'package:keel_ui/src/modules/tools/model/tool.dart';

part 'src/hook_resolution.dart';
part 'src/hook_turn.dart';
part 'src/hook_render.dart';
part 'src/hook_wrappers.dart';
