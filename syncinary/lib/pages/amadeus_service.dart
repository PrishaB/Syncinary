import 'dart:convert';
import 'package:http/http.dart' as http;
 
class AmadeusService {
  static const _proxyUrl = 'http://localhost:3000';
 
  /// Searches outbound flights. Pass [returnDate] for a round trip —
  /// each returned offer will include a `departure_token` you pass to
  /// [searchReturnFlights] to get that offer's return-leg options.
  /// Omit [returnDate] for a one-way search.
  Future<List<dynamic>> searchFlights({
    required String origin,
    required String destination,
    required String departureDate,
    int adults = 1,
    String? returnDate,
  }) async {
    final uri = Uri.parse('$_proxyUrl/flights').replace(
      queryParameters: {
        'origin': origin,
        'destination': destination,
        'departureDate': departureDate,
        'adults': adults.toString(),
        if (returnDate != null) 'returnDate': returnDate,
      },
    );
    final res = await http.get(uri);
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as List<dynamic>;
    } else {
      throw Exception('Flight search failed: ${res.body}');
    }
  }
 
  /// Given a round-trip outbound offer's `departure_token`, returns that
  /// offer's matching return-leg options.
  Future<List<dynamic>> searchReturnFlights({
    required String origin,
    required String destination,
    required String departureDate,
    required String returnDate,
    required String departureToken,
    int adults = 1,
  }) async {
    final uri = Uri.parse('$_proxyUrl/flights/return').replace(
      queryParameters: {
        'origin': origin,
        'destination': destination,
        'departureDate': departureDate,
        'returnDate': returnDate,
        'adults': adults.toString(),
        'departureToken': departureToken,
      },
    );
    final res = await http.get(uri);
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as List<dynamic>;
    } else {
      throw Exception('Return flight search failed: ${res.body}');
    }
  }
 
  /// Given a selected offer's `booking_token`, returns SerpApi's raw
  /// `booking_options` array (airline/OTA names, prices, and either a
  /// direct `url` or a `post_data` + `booking_request.url` pair).
  Future<List<dynamic>> getBookingOptions({
    required String origin,
    required String destination,
    required String departureDate,
    required String bookingToken,
    int adults = 1,
    String? returnDate,
  }) async {
    final uri = Uri.parse('$_proxyUrl/flights/booking').replace(
      queryParameters: {
        'origin': origin,
        'destination': destination,
        'departureDate': departureDate,
        'adults': adults.toString(),
        'bookingToken': bookingToken,
        if (returnDate != null) 'returnDate': returnDate,
      },
    );
    final res = await http.get(uri);
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as List<dynamic>;
    } else {
      throw Exception('Booking lookup failed: ${res.body}');
    }
  }
}
 