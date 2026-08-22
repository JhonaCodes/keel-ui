/// Respaldo del catálogo en UN archivo portable, con selección por
/// secciones. Distinto del mirror git (`catalog_sync`), que sincroniza
/// TODO contra un repo: acá el usuario elige qué viaja, el contenido de las
/// bases de saber locales viaja con ellas, y los secrets solo entran por
/// decisión explícita — nunca por defecto.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:logger_rs/logger_rs.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/core/ui/form_panel.dart';
import 'package:keel_ui/src/integrations/catalog_sync/catalog_sync.dart';
import 'package:keel_ui/src/modules/agent_profiles/viewmodel/agent_profiles_viewmodel.dart';
import 'package:keel_ui/src/modules/knowledge/model/knowledge_base.dart';
import 'package:keel_ui/src/modules/knowledge/viewmodel/knowledge_viewmodel.dart';
import 'package:keel_ui/src/modules/mcp_servers/viewmodel/mcp_servers_viewmodel.dart';
import 'package:keel_ui/src/modules/rules/viewmodel/rules_viewmodel.dart';
import 'package:keel_ui/src/modules/secrets/viewmodel/secrets_viewmodel.dart';
import 'package:keel_ui/src/modules/skills/viewmodel/skills_viewmodel.dart';
import 'package:keel_ui/src/modules/stations/viewmodel/stations_viewmodel.dart';
import 'package:keel_ui/src/modules/tools/viewmodel/tools_viewmodel.dart';
import 'package:keel_ui/src/modules/workflows/viewmodel/workflows_viewmodel.dart';

part 'src/backup_file.dart';
part 'src/catalog_backup_viewmodel.dart';
part 'src/ui/backup_panels.dart';
