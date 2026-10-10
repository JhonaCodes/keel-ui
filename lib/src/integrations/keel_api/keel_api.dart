/// The client side of keel-api: the person's own Keel server, reached over
/// HTTPS with the session of their account.
///
/// keel-ui works fully local without it. Signing in is optional and only
/// unlocks what the server knows: the nodes enrolled with it, the task queue
/// and the sessions every node reports.
///
/// This library is the only place that knows about `package:http`, the
/// `Authorization` header and the fields keel-api stores as JSON inside a
/// string. Nothing above it sees a network exception: every call answers
/// `Result<T, KeelApiFailure>`.
///
/// Tokens never reach a log, an argv or a `toString`. The access token lives
/// in memory only; the refresh token in a file only this user can read
/// ([KeelCredentialsStore]).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:logger_rs/logger_rs.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:reactive_notifier/reactive_notifier.dart';
import 'package:result_controller/result_controller.dart';

part 'src/access_token_source.dart';
part 'src/keel_api_client.dart';
part 'src/keel_api_failure.dart';
part 'src/keel_api_paths.dart';
part 'src/keel_api_service.dart';
part 'src/keel_credentials.dart';
part 'src/keel_json.dart';
