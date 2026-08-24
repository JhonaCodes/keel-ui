/// Qué versión de Keel estás corriendo, y el botón para pasarte a la nueva.
///
/// Keel se corre desde su propio código —`flutter run -d macos` sobre el
/// repo— así que "actualizar" no es bajarse un `.dmg`: es traer los commits
/// nuevos y volver a construir. Eso hoy se hace en una terminal, lo cual
/// significa que se hace cuando te acordás.
///
/// Acá se contestan las tres preguntas de esa rutina sin salir de la app:
///
/// | Pregunta | De dónde sale |
/// |---|---|
/// | ¿Qué código tengo? | `git log -1` en el repo desde donde arrancó |
/// | ¿Hay algo nuevo? | `git fetch` + los commits que faltan |
/// | ¿Estoy corriendo lo que tengo? | la fecha del binario contra la del commit |
///
/// Esa última pregunta es la que nadie se hace y la que más muerde: traer
/// los commits no cambia lo que está corriendo. El binario que tenés abierto
/// es el de la última vez que construiste, y esta pantalla lo dice en vez de
/// dejarte creer que "actualizar" ya te puso en la versión nueva.
library;

import 'dart:async';
import 'dart:io';
// `AppExitType` vive en dart:ui; services no lo reexporta.
import 'dart:ui' show AppExitType;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:logger_rs/logger_rs.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/core/services/external_link_service.dart';
import 'package:keel_ui/src/integrations/app_update/release_version.dart';
import 'package:keel_ui/src/modules/app_status/viewmodel/app_status_viewmodel.dart';
import 'package:keel_ui/src/modules/projects/viewmodel/projects_viewmodel.dart';

export 'release_version.dart';

part 'src/keel_source.dart';
part 'src/release_channel.dart';
part 'src/update_probe.dart';
part 'src/update_plan.dart';
part 'src/update_run.dart';
part 'src/update_viewmodel.dart';
part 'src/ui/keel_version_section.dart';
