/// La mitad con Flutter del puente de catálogo: el ViewModel que publica
/// el enganche al arrancar y la sección de Ajustes que muestra el bloque
/// para pegar en ChatGPT desktop.
///
/// La mitad que de verdad habla el protocolo vive en
/// `catalog_bridge_core.dart`, en Dart puro, porque la comparte el binario
/// del worker — que se compila sin engine. Este archivo la reexporta para
/// que dentro de la app alcance con un solo import.
library;

import 'dart:async';
import 'dart:io' show pid;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:keel_core/integrations/catalog_mcp/catalog_mcp.dart';
import 'package:logger_rs/logger_rs.dart';
import 'package:path_provider/path_provider.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/l10n/generated/app_localizations.dart';
import 'package:keel_ui/src/integrations/catalog_bridge/catalog_bridge_core.dart';

export 'package:keel_ui/src/integrations/catalog_bridge/catalog_bridge_core.dart';

part 'src/catalog_bridge_viewmodel.dart';
part 'src/ui/chatgpt_catalog_section.dart';
