/// El vault: TODO el sistema —catálogo, ajustes y qué secrets existen— en un
/// `keel-backup.zip` dentro de una carpeta que vos versionás con git.
///
/// El problema que resuelve es de supervivencia: hoy skills, agentes,
/// proyectos, tools y bases viven en un LMDB dentro de Application Support,
/// y desinstalar la app se los lleva a todos. El vault los pone donde una
/// desinstalación no llega, y `clonar → restaurar` los devuelve enteros en
/// una máquina nueva.
///
/// Lo efímero NO entra, a propósito: hilos de chat, sesiones, adjuntos,
/// registros de prompts y el token de la API de trabajos. Los VALORES de los
/// secrets tampoco — el vault va a un remoto, y un valor en la historia de
/// git no se borra nunca. Viajan solo sus nombres, y del otro lado quedan
/// pendientes de completar.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
// `AppExitResponse` vive en dart:ui; material no lo reexporta.
import 'dart:ui' show AppExitResponse;

import 'package:archive/archive.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:logger_rs/logger_rs.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/l10n/generated/app_localizations.dart';
import 'package:keel_ui/src/core/ui/form_panel.dart';
import 'package:keel_ui/src/shared/shared.dart';
import 'package:keel_ui/src/integrations/catalog_shape/catalog_shape.dart';
import 'package:keel_ui/src/modules/knowledge/model/knowledge_base.dart';
import 'package:keel_ui/src/modules/knowledge/viewmodel/knowledge_viewmodel.dart';
import 'package:keel_ui/src/modules/secrets/viewmodel/secrets_viewmodel.dart';
import 'package:keel_ui/src/modules/settings/model/app_settings.dart';
import 'package:keel_ui/src/modules/app_status/viewmodel/app_status_viewmodel.dart';
import 'package:keel_ui/src/modules/settings/viewmodel/settings_viewmodel.dart';

part 'src/system_vault_viewmodel.dart';
part 'src/vault_auto_backup.dart';
part 'src/ui/vault_onboarding.dart';
part 'src/ui/vault_panels.dart';
part 'src/vault_archive.dart';
part 'src/vault_git.dart';
