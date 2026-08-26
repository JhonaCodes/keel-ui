/// Los requerimientos entre proyectos, servidos al turno que los necesita.
///
/// El alcance sale de la URL, no de un argumento del modelo: de la ruta salen
/// el proyecto y la sesión, y de ahí se deriva de qué lado está parado quien
/// llama. Es lo que hace que "cerrar es del origen" no sea una promesa sino
/// una comprobación.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dart_mcp/server.dart' as mcp;
import 'package:logger_rs/logger_rs.dart';
import 'package:stream_channel/stream_channel.dart';

import 'package:keel_ui/src/modules/agent_profiles/viewmodel/agent_profiles_viewmodel.dart';
import 'package:keel_ui/src/modules/projects/model/project.dart';
import 'package:keel_ui/src/modules/projects/viewmodel/projects_viewmodel.dart';
import 'package:keel_ui/src/modules/requirements/model/internal_requirement.dart';
import 'package:keel_ui/src/modules/requirements/viewmodel/requirements_viewmodel.dart';
import 'package:keel_ui/src/integrations/system_prompt/system_prompt.dart';

part 'src/requirement_render.dart';
part 'src/requirements_mcp_server.dart';
