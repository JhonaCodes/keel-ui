/// `/v1/keel-bot/nodes`, with the account's session.
library;

import 'package:result_controller/result_controller.dart';

import 'package:keel_ui/src/integrations/keel_api/keel_api.dart';
import 'package:keel_ui/src/modules/keel_remote/model/keel_node.dart';

class KeelNodesRepository {
  const KeelNodesRepository();

  KeelApiClient get _client => KeelApiService.client.notifier;

  Future<Result<List<KeelNode>, KeelApiFailure>> list() async =>
      (await _client.getList(
        KeelApiPaths.nodes,
      )).map((rows) => rows.map(KeelNode.fromJson).toList(growable: false));

  /// Enrolls this keel-ui as a `desktop` node with the signed-in person's
  /// session. Enrolling an id that exists rotates its token.
  ///
  /// Nothing in keel-ui calls it yet: the node side (taking tasks, reporting
  /// status) is its own phase, built on keel-core's node link, and it starts
  /// here — with the session [KeelAccountViewModel] keeps.
  Future<Result<KeelNodeEnrollment, KeelApiFailure>> enrollDesktop({
    required String id,
    required String label,
  }) async => (await _client.postObject(
    KeelApiPaths.enrollNode,
    body: <String, dynamic>{
      'id': id,
      'kind': KeelNode.desktopKind,
      'label': label,
    },
  )).map(KeelNodeEnrollment.fromJson);
}
