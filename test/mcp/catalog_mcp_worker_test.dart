import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:keel_core/core/host/keel_host.dart';
import 'package:keel_core/core/keel_core_runtime.dart';
import 'package:keel_core/core/store/keel_store.dart';
import 'package:keel_core/integrations/catalog_mcp/catalog_mcp.dart';
import 'package:keel_ui/src/core/host/keel_host_impl.dart';
import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/integrations/catalog_bridge/catalog_bridge_core.dart';

/// El borde de riesgo de esta feature NO es una regla de negocio: es el
/// cableado. Un cliente de escritorio ajeno lanza un proceso, ese proceso
/// habla MCP por stdio, y del otro lado tiene que aparecer el catálogo real
/// de la app corriendo. Cualquier mock en el medio —del canal, del HTTP, de
/// las tools— probaría el mock.
///
/// Así que acá no hay ninguno: servidor de catálogo real levantado sobre un
/// store en memoria, archivo de enganche real en disco, y el relay hablando
/// por un canal de bytes de punta a punta. Lo que se afirma es lo que ve
/// ChatGPT: los nombres de tools que le llegan.
void main() {
  late Directory temporary;
  late String endpointPath;
  late _MemoryStore store;

  setUpAll(LocalDatabase.markUnavailable);

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('keel_catalog_bridge');
    endpointPath = CatalogEndpointFile.pathIn(temporary.path);

    store = _MemoryStore();
    KeelHost.instance = const KeelHostImpl();
    KeelCoreRuntime.start(store: store, host: const KeelHostImpl());

    await CatalogMcpServer.ensureStarted();
    await CatalogEndpointFile.publish(
      endpointPath,
      CatalogEndpoint(
        port: CatalogMcpServer.port!,
        token: CatalogMcpServer.token!,
        pid: 0,
      ),
    );
  });

  tearDown(() async {
    await CatalogMcpServer.stop();
    if (temporary.existsSync()) temporary.deleteSync(recursive: true);
  });

  test(
    'por stdio el worker entrega las tools del catálogo y ninguna que abra '
    'una sesión',
    () async {
      final client = _StdioClient();
      unawaited(
        CatalogMcpBridge.serve(
          endpointPath: endpointPath,
          input: client.toWorker.stream,
          output: client.fromWorker.sink,
        ),
      );

      client.send({
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'initialize',
        'params': {
          'protocolVersion': '2024-11-05',
          'capabilities': <String, Object?>{},
          'clientInfo': {'name': 'chatgpt-desktop-test', 'version': '1.0.0'},
        },
      });
      final initialize = await client.replyAt(0);

      expect(
        ((initialize['result'] as Map)['serverInfo'] as Map)['name'],
        kCatalogMcpServerKey,
        reason: 'el handshake no llegó al servidor del catálogo',
      );

      // Notificación: sin `id`, el host contesta 202 y no hay qué devolver.
      // Va antes de `tools/list` para que el orden de las respuestas sea el
      // que el test asume.
      client.send({'jsonrpc': '2.0', 'method': 'notifications/initialized'});
      client.send({'jsonrpc': '2.0', 'id': 2, 'method': 'tools/list'});
      final listed = await client.replyAt(1);

      final names = [
        for (final tool in (listed['result'] as Map)['tools'] as List)
          (tool as Map)['name'] as String,
      ];

      expect(
        names,
        containsAll(<String>[
          'list_catalog',
          'get_item',
          'create_skill',
          'update_skill',
          'create_workflow',
          'create_project',
          'read_knowledge_document',
        ]),
        reason: 'ChatGPT no podría leer ni escribir el catálogo',
      );
      // El punto de producto: ChatGPT es el trabajador, no el lanzador.
      expect(
        names,
        isNot(
          anyElement(
            anyOf(
              'open_project_session',
              'reply_in_session',
              'intervene',
              'send_message',
            ),
          ),
        ),
        reason: 'una tool que abre una sesión gastaría saldo de modelos',
      );

      await client.close();
    },
  );

  test('con Keel cerrado contesta un error JSON-RPC, no se cuelga', () async {
    await File(endpointPath).delete();

    final client = _StdioClient();
    unawaited(
      CatalogMcpBridge.serve(
        endpointPath: endpointPath,
        input: client.toWorker.stream,
        output: client.fromWorker.sink,
      ),
    );

    client.send({'jsonrpc': '2.0', 'id': 1, 'method': 'tools/list'});
    final reply = await client.replyAt(0);

    expect(reply['id'], 1);
    expect((reply['error'] as Map)['message'], contains('Keel'));

    await client.close();
  });
}

/// Un cliente MCP de juguete sobre bytes: escribe líneas en el stdin del
/// relay y junta las que salen por su stdout.
class _StdioClient {
  _StdioClient() {
    _subscription = fromWorker.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_lines.add);
  }

  final toWorker = StreamController<List<int>>();
  final fromWorker = StreamController<List<int>>();
  final _lines = <String>[];
  late final StreamSubscription<String> _subscription;

  void send(Map<String, dynamic> message) =>
      toWorker.add(utf8.encode('${jsonEncode(message)}\n'));

  /// La respuesta número [index], esperando a que llegue.
  ///
  /// Se sondea en vez de usar un `await` sobre el stream porque el canal es
  /// de una sola suscripción y el test lee varias respuestas seguidas. El
  /// tope son cinco segundos, y vuelve apenas la línea está.
  Future<Map<String, dynamic>> replyAt(int index) async {
    for (var attempt = 0; attempt < 200 && _lines.length <= index; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
    expect(
      _lines.length,
      greaterThan(index),
      reason: 'el worker no contestó el mensaje ${index + 1}',
    );
    return jsonDecode(_lines[index]) as Map<String, dynamic>;
  }

  Future<void> close() async {
    await toWorker.close();
    await _subscription.cancel();
    await fromWorker.close();
  }
}

/// Mismo molde que `test/agents/agents_persistence_safety_test.dart`: el
/// catálogo tiene que venir de un store de verdad, solo que en memoria.
class _MemoryStore implements KeelStore {
  final Map<String, Map<String, dynamic>> records = {};

  @override
  Future<void> put(String key, Map<String, dynamic> data) async =>
      records[key] = data;

  @override
  Future<Map<String, dynamic>?> get(String key) async => records[key];

  @override
  Future<void> delete(String key) async => records.remove(key);

  @override
  Future<List<Map<String, dynamic>>> getAllWithPrefix(String prefix) async => [
    for (final entry in records.entries)
      if (entry.key.startsWith(prefix)) entry.value,
  ];

  @override
  Future<List<({String key, Map<String, dynamic> data})>> entriesWithPrefix(
    String prefix,
  ) async => [
    for (final entry in records.entries)
      if (entry.key.startsWith(prefix)) (key: entry.key, data: entry.value),
  ];

  @override
  Future<void> replaceAllWithPrefix(
    String prefix,
    List<Map<String, dynamic>> items,
  ) async {
    records.removeWhere((key, _) => key.startsWith(prefix));
    for (final item in items) {
      records['$prefix${item['id']}'] = item;
    }
  }
}
