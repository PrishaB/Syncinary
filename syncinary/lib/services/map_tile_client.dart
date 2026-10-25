import 'package:http/http.dart' as http;
import 'package:http/retry.dart';

/// Retries temporary tile connection failures without hiding persistent errors.
/// Browser connection resets arrive as ClientException, not HTTP status codes.
class MapTileClient extends http.BaseClient {
  MapTileClient({http.Client? client, Duration Function(int)? retryDelay}) {
    _client = RetryClient(
      client ?? http.Client(),
      retries: 2,
      when: (response) => const {502, 503, 504}.contains(response.statusCode),
      whenError: (error, _) =>
          !_closed &&
          error is http.ClientException &&
          error is! http.RequestAbortedException,
      delay:
          retryDelay ??
          (attempt) => Duration(milliseconds: 400 * (attempt + 1)),
    );
  }

  late final RetryClient _client;
  bool _closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _client.send(request);

  @override
  void close() {
    _closed = true;
    _client.close();
  }
}
