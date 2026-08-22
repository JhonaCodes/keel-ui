/// Los tableros de ESTE proyecto, servidos al turno que los escribe.
///
/// El alcance sale de la URL igual que en el plan, el roadmap y los
/// requerimientos: un turno no puede nombrar un proyecto que no es el suyo,
/// así que tampoco puede dejarle un tablero.
///
/// Hay cinco tools y todas son de DEFINICIÓN. **No existe `run_board`, y es
/// a propósito**: un tablero dispara pedidos reales contra tu API y comandos
/// en tu máquina. El agente arma el instrumento; la palanca la bajás vos.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dart_mcp/server.dart' as mcp;
import 'package:logger_rs/logger_rs.dart';
import 'package:stream_channel/stream_channel.dart';

import 'package:keel_ui/src/integrations/genui/genui.dart';
import 'package:keel_ui/src/modules/boards/model/board.dart';
import 'package:keel_ui/src/modules/boards/viewmodel/boards_viewmodel.dart';
import 'package:keel_ui/src/modules/projects/viewmodel/projects_viewmodel.dart';

part 'src/boards_mcp_server.dart';
