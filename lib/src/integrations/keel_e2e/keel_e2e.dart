/// El supervisor de keel-e2e del lado de keel-ui: dónde está el binario,
/// dónde vive su `dataDir`, y la entrada MCP del paso que lo usa.
///
/// keel-e2e es su propio proceso (architecture §5): keel-ui lo arranca
/// perezoso, la primera vez que una pestaña E2E se abre o un paso de
/// keel-e2e está por correr, nunca al iniciar la app.
library;

import 'dart:async';
import 'dart:io';

import 'package:keel_e2e_panel/keel_e2e_panel.dart'
    show EngineConnection, KeelE2eHostConfig, KeelE2eHostService;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:result_controller/result_controller.dart';
import 'package:window_manager/window_manager.dart';

import 'package:keel_core/modules/projects/model/project.dart';

part 'src/keel_e2e_attach.dart';
part 'src/keel_e2e_binary.dart';
part 'src/keel_e2e_data_dir.dart';
part 'src/keel_e2e_quit_hook.dart';
