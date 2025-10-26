class Contractor {
  final String id;
  final String name;
  final List<String> types;
  final String? phone;
  final String? address;
  final double lat, lng;
  final double? distanceM;

  Contractor({
    required this.id,
    required this.name,
    required this.types,
    this.phone,
    this.address,
    required this.lat,
    required this.lng,
    this.distanceM,
  });

  factory Contractor.fromJson(Map<String, dynamic> j) => Contractor(
    id: j['id'] as String,
    name: j['name'] as String,
    types: (j['types'] as List).map((e) => e.toString()).toList(),
    phone: j['phone'] as String?,
    address: j['address'] as String?,
    lat: (j['lat'] as num).toDouble(),
    lng: (j['lng'] as num).toDouble(),
    distanceM: j['distance_m'] == null
        ? null
        : (j['distance_m'] as num).toDouble(),
  );
}
