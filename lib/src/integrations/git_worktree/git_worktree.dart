/// En qué worktree del repo está parado un proyecto, y cómo volver al
/// principal sin perder la rama.
///
/// Trabajar en dos cosas distintas del mismo repo a la vez se resuelve con
/// `git worktree`: dos carpetas, dos ramas, un solo historial. Lo que faltaba
/// es que **la app se entere**. Sin eso pasan dos cosas, las dos silenciosas:
/// la pantalla no distingue una carpeta de la otra —dos proyectos que se
/// llaman parecido y apuntan al mismo repo— y el agente arranca su turno sin
/// saber que la rama ya existe, así que se crea otra.
///
/// Acá se lee eso —una sola pasada de `git worktree list`— y se ofrece el
/// único movimiento que hace falta cuando el trabajo paralelo terminó:
/// **unificar**, que trae la rama al worktree principal y saca la carpeta
/// de al lado.
///
/// Nada de esto configura nada. Un worktree se detecta o no se detecta; no
/// hay una casilla que marcar, y esa es justamente la idea.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logger_rs/logger_rs.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/l10n/generated/app_localizations.dart';
import 'package:keel_ui/src/core/ui/form_panel.dart';
import 'package:keel_ui/src/modules/app_status/viewmodel/app_status_viewmodel.dart';
import 'package:keel_ui/src/modules/projects/model/project.dart';
import 'package:keel_ui/src/modules/projects/viewmodel/projects_viewmodel.dart';
import 'package:keel_ui/src/modules/workspace/model/running_work.dart';

part 'src/worktree_place.dart';
part 'src/worktree_probe.dart';
part 'src/worktree_plan.dart';
part 'src/worktree_unify.dart';
part 'src/worktree_viewmodel.dart';
part 'src/ui/worktree_strip.dart';
part 'src/ui/worktree_panel.dart';
