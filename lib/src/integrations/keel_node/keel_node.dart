/// This PC as a keel-api node (`kind: desktop`): the Keel app sends it work,
/// and it reports what its sessions do, on keel-core's shared node link.
///
/// What lives here is what makes the link run on keel-ui:
///
/// - [DesktopNodeRuntime]: the session engine ([CoreEngine]) over the same
///   `ProjectsStore` the widgets use, the node's [KeelProjection]
///   ([ProjectionHolder]) and the [NodeLink] that takes the app's tasks,
///   with the node's own `knt_` token.
/// - [KeelUiNodeHost]: how this PC runs a command the app sent, without
///   moving what the person is looking at.
/// - [DesktopKeelAi]: this PC's Keel AI, the one the app chats with
///   (`keelai.*`) and the work naming no workflow goes to. «Aceptar todo» on
///   this PC's sessions is keel-core's [NodeAutoApprove].
/// - [ServerOnlyTasks]: the task types only keel-server runs, refused here at
///   once.
/// - [NodeMemoryLog]: the link's recent lines, in memory, for the Keel
///   panel's status.
///
/// Nothing here holds the token on disk: `KeelNodeCredentialsStore` (the
/// `keel_api` integration) keeps it in an owner-only file, and the link reads
/// it from memory on every call.
library;

import 'dart:async';
import 'dart:io';

import 'package:keel_core/engine/core_engine.dart';
import 'package:keel_core/integrations/machine/machine.dart';
import 'package:keel_core/integrations/node_keel_ai/node_keel_ai.dart';
import 'package:keel_core/integrations/node_link/node_link.dart';
import 'package:keel_core/modules/projects/model/project.dart';
import 'package:keel_core/modules/projects/service/projects_store.dart';
import 'package:keel_core/protocol/keel_protocol.dart';
import 'package:logger_rs/logger_rs.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:result_controller/result_controller.dart';

import 'package:keel_ui/src/integrations/keel_api/keel_api.dart';

part 'src/desktop_keel_ai.dart';
part 'src/desktop_node_identity.dart';
part 'src/desktop_node_runtime.dart';
part 'src/desktop_node_snapshot.dart';
part 'src/keel_ui_node_host.dart';
part 'src/node_memory_log.dart';
part 'src/server_only_tasks.dart';
