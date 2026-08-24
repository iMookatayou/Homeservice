// lib/models/place.dart
class Place {
  final String id;
  final String name;
  final double lat;
  final double lon;
  final String? address;
  final List<String> types;
  final double? distanceMeters;

  const Place({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
    this.address,
    this.types = const [],
    this.distanceMeters,
  });

  factory Place.fromJson(Map<String, dynamic> j) => Place(
    id: (j['id'] ?? '${j['lat']}_${j['lon']}').toString(),
    name: j['name']?.toString() ?? 'Unnamed',
    lat: (j['lat'] as num).toDouble(),
    lon: (j['lon'] as num).toDouble(),
    address: j['address']?.toString(),
    types: (j['types'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    distanceMeters: j['distance_m'] == null
        ? null
        : (j['distance_m'] as num).toDouble(),
  );
}
