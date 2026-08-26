/// El roadmap de un proyecto, leído del repo, con la toma de tareas resuelta
/// contra la base local.
///
/// Reparto deliberado, y es toda la idea: la DEFINICIÓN de cada tarea vive en
/// la carpeta del proyecto —al lado del código, con rutas relativas a la raíz
/// del repo, legible para cualquiera que la abra— y la TOMA vive en la base
/// local, porque es lo único que necesita ser atómico y lo único que no es
/// propiedad del código sino del momento.
///
/// La carpeta está en el repo pero NO se comitea: `ensureRoadmapIgnored` la
/// agrega al `.gitignore` cuando arranca la sesión que la define. Es la
/// libreta de trabajo de quien usa Keel, no una entrega del proyecto.
///
/// El alcance no es un argumento que manda el modelo: sale de la URL con la
/// que se le entregó este servidor al turno. Un turno del proyecto A no
/// puede tomar una tarea del proyecto B aunque lo pida — no tiene cómo
/// nombrarlo.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dart_mcp/server.dart' as mcp;
import 'package:logger_rs/logger_rs.dart';
import 'package:stream_channel/stream_channel.dart';

import 'package:keel_ui/src/modules/agent_profiles/viewmodel/agent_profiles_viewmodel.dart';
import 'package:keel_ui/src/modules/roadmap/viewmodel/task_claims_viewmodel.dart';
import 'package:keel_ui/src/modules/projects/viewmodel/projects_viewmodel.dart';
import 'package:keel_ui/src/integrations/system_prompt/system_prompt.dart';

part 'src/roadmap_reader.dart';
part 'src/roadmap_gitignore.dart';
part 'src/roadmap_format_check.dart';
part 'src/roadmap_mcp_server.dart';
