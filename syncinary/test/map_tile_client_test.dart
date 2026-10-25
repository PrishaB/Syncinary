import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:syncinary/services/map_tile_client.dart';

void main() {
  final tile = Uri.parse('https://tile.openstreetmap.org/5/16/11.png');

  test('[202-1] a temporary tile connection failure is retried', () async {
    var calls = 0;
    final client = MapTileClient(
      client: MockClient((request) async {
        expect(request.url, tile);
        if (++calls == 1) throw http.ClientException('Failed to fetch', tile);
        return http.Response('tile bytes', 200);
      }),
      retryDelay: (_) => Duration.zero,
    );
    addTearDown(client.close);
    expect((await client.get(tile)).body, 'tile bytes');
    expect(calls, 2);
  });

  test('[202-3] persistent connection errors stop after two retries', () async {
    var calls = 0;
    final client = MapTileClient(
      client: MockClient((_) async {
        calls++;
        throw http.ClientException('Failed to fetch', tile);
      }),
      retryDelay: (_) => Duration.zero,
    );
    addTearDown(client.close);
    await expectLater(client.get(tile), throwsA(isA<http.ClientException>()));
    expect(calls, 3);
  });

  test(
    '[202-1] temporary HTTP failures retry but access/rate-limit errors do not',
    () async {
      for (final status in [502, 503, 504, 400, 401, 403, 404, 429]) {
        var calls = 0;
        final client = MapTileClient(
          client: MockClient((_) async {
            calls++;
            return http.Response('', status);
          }),
          retryDelay: (_) => Duration.zero,
        );
        expect((await client.get(tile)).statusCode, status);
        expect(calls, status >= 500 ? 3 : 1);
        client.close();
      }
    },
  );

  test('[202-3] cancelled tile requests are never retried', () async {
    var calls = 0;
    final client = MapTileClient(
      client: MockClient((_) async {
        calls++;
        throw http.RequestAbortedException(tile);
      }),
      retryDelay: (_) => Duration.zero,
    );
    addTearDown(client.close);
    await expectLater(
      client.get(tile),
      throwsA(isA<http.RequestAbortedException>()),
    );
    expect(calls, 1);
  });
}