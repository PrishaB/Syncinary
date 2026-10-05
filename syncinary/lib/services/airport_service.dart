import 'dart:convert';
import 'package:http/http.dart' as http;

class Airport {
  const Airport({
    required this.code,
    required this.name,
    required this.address,
    this.attributions = const [],
  });

  final String code;
  final String name;
  final String address;
  final List<String> attributions;
  String get label => '$name ($code)';
}

class AirportSuggestions {
  const AirportSuggestions(this.airports, this.source);
  final List<Airport> airports;
  final String source;
}

class AirportService {
  AirportService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Future<AirportSuggestions> search(String query) async {
    final uri = Uri.parse(
      'http://localhost:3000/airports',
    ).replace(queryParameters: {'q': query});
    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('Airport suggestions unavailable');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final airports = (data['airports'] as List).map((raw) {
      final code = raw['code'] as String;
      if (!RegExp(r'^[A-Z]{3}$').hasMatch(code)) {
        throw const FormatException('Invalid airport code');
      }
      return Airport(
        code: code,
        name: raw['name'] as String,
        address: raw['address'] as String,
        attributions: (raw['attributions'] as List? ?? [])
            .map((a) => a['provider'] as String? ?? '')
            .where((a) => a.isNotEmpty)
            .toList(),
      );
    }).toList();
    return AirportSuggestions(airports, data['source'] as String);
  }

  void dispose() => _client.close();
}
