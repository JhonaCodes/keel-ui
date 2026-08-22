/// Respaldo del catálogo en UN archivo portable, con selección por
/// secciones. Distinto del vault (`system_vault`), que respalda TODO el
/// sistema en una carpeta versionada: acá el usuario elige qué viaja y a
/// dónde, y —lo único que el vault no hace nunca— los VALORES de los
/// secrets pueden viajar, por decisión explícita y nunca por defecto.
///
/// Ese es el reparto: el vault es el respaldo que se sube a un remoto, este
/// archivo es el que se lleva a mano de una máquina propia a otra.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:logger_rs/logger_rs.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/core/ui/form_panel.dart';
import 'package:keel_ui/src/integrations/catalog_shape/catalog_shape.dart';
import 'package:keel_ui/src/modules/knowledge/model/knowledge_base.dart';
import 'package:keel_ui/src/modules/knowledge/viewmodel/knowledge_viewmodel.dart';
import 'package:keel_ui/src/modules/secrets/viewmodel/secrets_viewmodel.dart';

part 'src/backup_file.dart';
part 'src/catalog_backup_viewmodel.dart';
part 'src/ui/backup_panels.dart';
