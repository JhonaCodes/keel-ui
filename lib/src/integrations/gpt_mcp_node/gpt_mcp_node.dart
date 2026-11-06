/// GPT MCP from this PC: keel-core's [GptMcpNode] started as node `pc`, and
/// the Settings section where the owner manages it and the server's (through
/// keel-api's `gpt.*` tasks): the ChatGPT connection, the folders it reaches,
/// new folders for it, and the chat's access requests.
library;

import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:keel_core/integrations/gpt_mcp/gpt_mcp.dart';
import 'package:keel_core/modules/secrets/service/secrets_store.dart';
import 'package:logger_rs/logger_rs.dart';
import 'package:path/path.dart' as p;
import 'package:reactive_notifier/reactive_notifier.dart';
import 'package:result_controller/result_controller.dart';

import 'package:keel_ui/l10n/generated/app_localizations.dart';
import 'package:keel_ui/src/integrations/keel_api/keel_api.dart';
import 'package:keel_ui/src/modules/keel_remote/model/keel_account_state.dart';
import 'package:keel_ui/src/modules/keel_remote/model/remote_task.dart';
import 'package:keel_ui/src/modules/keel_remote/repository/keel_nodes_repository.dart';
import 'package:keel_ui/src/modules/keel_remote/repository/remote_tasks_repository.dart';

part 'src/gpt_mcp_node_state.dart';
part 'src/gpt_mcp_node_viewmodel.dart';
part 'src/gpt_mcp_server_repository.dart';
part 'src/gpt_mcp_server_viewmodel.dart';
part 'src/ui/gpt_mcp_section.dart';
