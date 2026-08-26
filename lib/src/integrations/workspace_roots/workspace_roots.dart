/// Dónde trabaja el usuario, en serio: los discos que tiene montados y las
/// carpetas donde de verdad están sus proyectos.
///
/// La app venía asumiendo un solo lugar. El selector de carpeta abría donde
/// el sistema quisiera, y un agente 1:1 arranca en `$HOME` porque no tiene
/// proyecto asignado. Con los proyectos en otra partición —`/Volumes/Data`,
/// `D:\`, un disco externo— eso significa que ni el usuario ni el agente
/// llegan: el usuario navega el árbol entero a mano cada vez, y el agente
/// busca en el disco equivocado o directamente inventa la ruta.
///
/// Acá hay dos cosas, y ninguna adivina:
///
/// - [mountedVolumeRoots] — los volúmenes montados AHORA, preguntándole al
///   sistema operativo. Es lo que existe, no lo que se supone que existe.
/// - [WorkspaceRootsService] — las rutas que este usuario usó, en orden de
///   uso, persistidas. Es lo que le importa a él, que no es lo mismo.
///
/// Lo segundo es lo que alimenta la sección PROYECTOS CONOCIDOS del prompt
/// de un agente sin proyecto: en vez de recorrer discos, lee una lista de
/// rutas absolutas que ya son las suyas.
library;

import 'dart:async';
import 'dart:io';

import 'package:logger_rs/logger_rs.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/core/services/local_database.dart';

part 'src/mounted_volumes.dart';
part 'src/workspace_root.dart';
part 'src/workspace_root_cache.dart';
