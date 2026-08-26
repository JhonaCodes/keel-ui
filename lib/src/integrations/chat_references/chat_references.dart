/// Las referencias explícitas del chat: `/` carpetas, `@` agentes,
/// `$` skills y reglas, `#` saber.
///
/// Nació adentro del chat de una sesión (F38) y ahí se quedó: Keel AI, el
/// chat 1:1 y el hilo de un requerimiento tenían un `TextField` pelado. En
/// esos tres lugares es donde MÁS falta —Keel AI existe para construir la
/// configuración, y no podía nombrar la skill que estaba por tocar— así que
/// lo que era de un módulo pasó a ser de la app.
///
/// Lo que cambia entre un lugar y otro es UNA cosa: qué universo se puede
/// nombrar. Eso es [ChatReferenceScope]:
///
/// - [ProjectReferenceScope] — adentro de una sesión: las carpetas del
///   proyecto y los miembros del canal. Es el comportamiento de F38, intacto.
/// - [GlobalReferenceScope] — sin proyecto: las carpetas de los proyectos
///   registrados y las raíces conocidas ([WorkspaceRootsService]), y todos
///   los agentes del catálogo.
///
/// Las skills, las reglas y el saber no dependen del lugar: son catálogos
/// globales y se leen igual desde los dos.
///
/// Lo que se inserta en el texto es un enlace Markdown legible con destino
/// `keel://` tipado: el usuario ve el nombre que eligió y el runtime conserva
/// el id o la ruta exacta, así dos recursos parecidos no se confunden.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

import 'package:keel_ui/src/integrations/workspace_roots/workspace_roots.dart';
import 'package:keel_ui/src/modules/agent_profiles/model/agent_profile.dart';
import 'package:keel_ui/src/modules/agent_profiles/viewmodel/agent_profiles_viewmodel.dart';
import 'package:keel_ui/src/modules/knowledge/model/knowledge_base.dart';
import 'package:keel_ui/src/modules/knowledge/model/knowledge_document.dart';
import 'package:keel_ui/src/modules/knowledge/viewmodel/knowledge_viewmodel.dart';
import 'package:keel_ui/src/modules/projects/model/project.dart';
import 'package:keel_ui/src/modules/projects/viewmodel/projects_viewmodel.dart';
import 'package:keel_ui/src/modules/rules/viewmodel/rules_viewmodel.dart';
import 'package:keel_ui/src/modules/skills/viewmodel/skills_viewmodel.dart';
import 'package:keel_ui/src/shared/shared.dart';

part 'src/chat_reference_kind.dart';
part 'src/chat_reference_query.dart';
part 'src/chat_reference_suggestion.dart';
part 'src/chat_reference_scope.dart';
part 'src/chat_reference_service.dart';
