import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/modules/catalog_locks/model/catalog_lock.dart';

void main() {
  test('uses stable public aliases and round-trips a persisted lock', () {
    final lock = CatalogLock(
      kind: CatalogLockKind.mcpServer,
      name: 'github',
      createdAt: DateTime.utc(2026, 8, 27),
    );

    expect(lock.key, 'mcp_server:github');
    expect(CatalogLock.fromJson(lock.toJson()), lock);
    expect(
      CatalogLockKind.tryFromAlias('knowledge_base'),
      CatalogLockKind.knowledgeBase,
    );
  });

  test('identifies boards without collisions across projects', () {
    expect(catalogBoardLockName('api', 'smoke'), 'api · smoke');
    expect(catalogBoardLockName('web', 'smoke'), 'web · smoke');
  });
}
