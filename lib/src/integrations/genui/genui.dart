/// Los tableros: una UI chiquita, generada, para probar tu propia app.
///
/// "GenUI" acá es un patrón, no un SDK. No hay ninguna dependencia nueva ni
/// ninguna llamada a un servicio: el que genera la interfaz es **un agente
/// de los que ya tenés registrados**, escribiendo una especificación por una
/// tool MCP local, y la app la renderiza con widgets de Flutter de verdad.
///
/// Por eso un tablero se puede leer, versionar, respaldar y corregir a mano.
/// No es una pantalla opaca que devolvió un servicio: es data.
///
/// Acá vive lo puro —plantillas, armado del pedido, validación de la
/// especificación— y el ejecutor, que es lo único que toca la red y los
/// procesos. Lo puro se prueba sin la app.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:keel_ui/src/modules/boards/model/board.dart';
import 'package:keel_ui/src/modules/boards/model/board_run.dart';
import 'package:keel_ui/src/shared/shared.dart';

part 'src/template.dart';
part 'src/board_spec_json.dart';
part 'src/board_executor.dart';
