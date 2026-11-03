/// GPT MCP on this PC: keel-core's [GptMcpNode] started as node `pc`, and the
/// Settings section where the owner turns the ChatGPT connection on or off,
/// grants folders and approves the chat's access requests.
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
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/l10n/generated/app_localizations.dart';
import 'package:keel_ui/src/modules/keel_remote/model/keel_account_state.dart';

part 'src/gpt_mcp_node_state.dart';
part 'src/gpt_mcp_node_viewmodel.dart';
part 'src/ui/gpt_mcp_section.dart';
