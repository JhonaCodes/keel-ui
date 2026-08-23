/// Un **paquete**: un agente, un workflow o una skill, en un zip, cerrado
/// sobre todo lo que necesita para funcionar del otro lado.
///
/// Distinto de los otros dos respaldos, y por eso vive aparte:
///
/// | | Qué lleva | Para quién |
/// |---|---|---|
/// | `system_vault` | TODO el sistema, versionado en git | vos, en otra máquina |
/// | `catalog_backup` | lo que elijas, en un JSON | vos, a mano |
/// | `catalog_bundle` | UNA cosa y sus dependencias | **otra persona** |
///
/// Esa última columna es la que manda en cada decisión de acá. Lo que sale
/// va a correr en la máquina de alguien que no escribió nada de esto, así
/// que el paquete se describe solo —un manifiesto que un catálogo podría
/// indexar sin abrirlo— y lo que entra se **revisa antes de instalarse**.
///
/// Un paquete NUNCA lleva valores de secrets. Lleva sus nombres, para que
/// del otro lado se sepa qué hay que crear.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:logger_rs/logger_rs.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/core/ui/form_panel.dart';
import 'package:keel_ui/src/shared/shared.dart';
import 'package:keel_ui/src/integrations/catalog_shape/catalog_shape.dart';
import 'package:keel_ui/src/modules/app_status/viewmodel/app_status_viewmodel.dart';
import 'package:keel_ui/src/modules/knowledge/model/knowledge_base.dart';
import 'package:keel_ui/src/modules/knowledge/viewmodel/knowledge_viewmodel.dart';
import 'package:keel_ui/src/modules/mcp_servers/model/mcp_server_config.dart';

part 'src/bundle_manifest.dart';
part 'src/bundle_closure.dart';
part 'src/bundle_archive.dart';
part 'src/bundle_audit.dart';
part 'src/bundle_job.dart';
part 'src/bundle_viewmodel.dart';
part 'src/ui/bundle_export_panel.dart';
part 'src/ui/bundle_import_panel.dart';
part 'src/ui/bundle_findings_view.dart';
