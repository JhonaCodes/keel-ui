import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:result_controller/result_controller.dart';

import 'package:keel_ui/src/integrations/keel_api/keel_api.dart';

/// A session whose access token already expired on the server.
class _ExpiredSession implements AccessTokenSource {
  String _token = 'kat_expired';
  int renewals = 0;

  @override
  Future<String?> accessToken() async => _token;

  @override
  Future<String?> renew() async {
    renewals++;
    _token = 'kat_renewed';
    return _token;
  }
}

void main() {
  test('an expired access token is renewed once and the request is repeated '
      'with the new one', () async {
    final sent = <String?>[];
    final session = _ExpiredSession();
    final client = KeelApiClient()
      ..useHttpClient(
        MockClient((request) async {
          sent.add(request.headers['Authorization']);
          if (request.headers['Authorization'] == 'Bearer kat_expired') {
            return http.Response(
              jsonEncode({'error': 'token expired', 'code': 'token_expired'}),
              401,
            );
          }
          return http.Response(
            jsonEncode([
              {'id': 'hp-server', 'kind': 'server', 'online': true},
            ]),
            200,
          );
        }),
      )
      ..point('https://api.example.com/', tokens: session);

    final nodes = await client.getList(KeelApiPaths.nodes);

    expect(nodes, isA<Ok<List<Map<String, dynamic>>, KeelApiFailure>>());
    expect(nodes.data.single['id'], 'hp-server');
    expect(sent, ['Bearer kat_expired', 'Bearer kat_renewed']);
    expect(session.renewals, 1);
  });

  test('the refresh token is kept in a file only its owner can read, and '
      'never printed', () async {
    final directory = await Directory.systemTemp.createTemp('keel_api_store_');
    addTearDown(() => directory.delete(recursive: true));
    final store = KeelCredentialsStore(directory: directory.path);
    const credentials = KeelCredentials(
      origin: 'https://api.example.com',
      username: 'jhona',
      refreshToken: 'krt_secret',
    );

    expect(await store.write(credentials), isTrue);

    final file = File('${directory.path}/${KeelCredentialsStore.fileName}');
    expect(file.statSync().mode & 0x1FF, KeelCredentialsStore.ownerOnlyMode);
    expect(await store.read(), credentials);
    expect('$credentials', isNot(contains('krt_secret')));
  });
}
