import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/trip_location.dart';

class PlaceService {
  PlaceService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _proxyUrl = String.fromEnvironment(
    'PROXY_URL',
    defaultValue: 'http://localhost:3000',
  );

  Future<List<TripLocation>> search(String query) async {
    final response = await _client
        .get(
          Uri.parse(
            '$_proxyUrl/places',
          ).replace(queryParameters: {'q': query.trim()}),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) throw Exception('Place search unavailable');
    final data = jsonDecode(response.body);
    if (data is! Map || data['places'] is! List) {
      throw const FormatException('Invalid place response');
    }
    return (data['places'] as List)
        .map(TripLocation.fromMap)
        .whereType<TripLocation>()
        .toList();
  }

  void dispose() => _client.close();
}
