/// El puente que deja a un cliente MCP de escritorio ajeno —ChatGPT
/// desktop— trabajar sobre el catálogo de Keel.
///
/// **Por qué esta mitad es Dart puro y vive separada del barril.** El
/// proceso que lanza ChatGPT se compila con `dart build cli`, o sea sin
/// engine de Flutter. Todo lo que `bin/catalog_mcp_worker.dart` importe
/// tiene que poder compilar ahí: ni `package:flutter/*`, ni
/// `reactive_notifier`, ni nada que arrastre `dart:ui`. El ViewModel y la
/// sección de ajustes viven en `catalog_bridge.dart`, que reexporta esta
/// librería; el worker importa ESTE archivo, nunca aquel.
///
/// **Por qué el worker no levanta sus propios stores**, que sería lo obvio.
/// Dos razones medidas, no de gusto:
///
/// 1. El backend de la app es `flutter_local_db`, y su API Dart reexporta
///    `path_provider` → `package:flutter/foundation.dart` → `dart:ui`. Un
///    binario sin engine no compila contra ella. No hay forma de importar
///    solo su FFI.
/// 2. Aun forzándolo, un segundo proceso escribiendo el mismo LMDB pierde
///    datos: `LocalDatabase` lee la base entera UNA vez y la deja en
///    memoria, y `replaceAllWithPrefix` decide qué borrar comparando
///    contra ese índice. Lo que escribiera el worker lo pisaría la app sin
///    que nadie se entere.
///
/// Así que el worker **relaya**: habla MCP por stdio con el cliente y lo
/// traduce a un POST contra el servidor de catálogo que la app corriendo ya
/// expone en loopback. El efecto secundario es el mejor de los dos mundos —
/// no es "la misma base", son los MISMOS stores vivos, así que una skill
/// creada desde ChatGPT aparece en keel-ui sin reiniciar nada.
///
/// El precio: Keel tiene que estar abierto. Cuando no lo está, el worker
/// contesta un error JSON-RPC que lo dice, en vez de colgarse.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_mcp/stdio.dart';
import 'package:path/path.dart' as p;

// Solo por la clave `keel-catalog`: el nombre con el que el servidor se
// registra es del motor, y escribirlo de nuevo acá sería una segunda verdad
// que se desincroniza en silencio.
import 'package:keel_core/integrations/catalog_mcp/catalog_mcp.dart'
    show kCatalogMcpServerKey;

part 'src/catalog_endpoint.dart';
part 'src/catalog_mcp_bridge.dart';
part 'src/catalog_worker_command.dart';
