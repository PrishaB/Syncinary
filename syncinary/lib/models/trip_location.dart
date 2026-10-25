/// A confirmed place saved with a schedule item. Legacy items have no location.
class TripLocation {
  const TripLocation({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.address = '',
  });

  final String name;
  final String address;
  final double latitude;
  final double longitude;

  bool get isValid =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude.abs() <= 90 &&
      longitude.abs() <= 180;

  static TripLocation? fromMap(dynamic data) {
    if (data is! Map || data['latitude'] is! num || data['longitude'] is! num) {
      return null;
    }
    final location = TripLocation(
      name: data['name'] is String ? data['name'] as String : '',
      address: data['address'] is String ? data['address'] as String : '',
      latitude: (data['latitude'] as num).toDouble(),
      longitude: (data['longitude'] as num).toDouble(),
    );
    return location.isValid ? location : null;
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'address': address,
    'latitude': latitude,
    'longitude': longitude,
  };
}
