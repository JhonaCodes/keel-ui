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
  /// `DesktopNodeViewModel` calls it when the person connects this PC as a
  /// node; the node runs from then on with the token it answers, not with
  /// the person's session.
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

  /// Unlinks node [id] with the person's session (`204`): its token stops
  /// working at once and it leaves the node list. Tasks bound to it keep
  /// their state on the server.
  Future<Result<void, KeelApiFailure>> unlink(String id) async =>
      (await _client.send('DELETE', KeelApiPaths.node(id))).map((_) {});
}
