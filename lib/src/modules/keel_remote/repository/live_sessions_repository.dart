/// `GET /v1/keel-bot/workers/sessions`: what every node that reported in
/// the last 30 s is running.
library;

import 'package:result_controller/result_controller.dart';

import 'package:keel_ui/src/integrations/keel_api/keel_api.dart';
import 'package:keel_ui/src/modules/keel_remote/model/live_session.dart';

class LiveSessionsRepository {
  const LiveSessionsRepository();

  KeelApiClient get _client => KeelApiService.client.notifier;

  Future<Result<List<LiveSession>, KeelApiFailure>> list() async =>
      (await _client.getObject(KeelApiPaths.workerSessions)).map(
        (json) => <LiveSession>[
          for (final row in json['sessions'] as List<Object?>? ?? const [])
            if (row is Map<String, dynamic>) LiveSession.fromJson(row),
        ],
      );
}
