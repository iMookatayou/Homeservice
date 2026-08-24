class User {
  final String id;
  final String name;
  final String email;
  final String role;

  const User({
    required this.id,
    required this.name,
    required this.email,
    this.role = 'member',
  });

  factory User.fromJson(Map<String, dynamic> j) => User(
    id: j['id']?.toString() ?? '',
    name: j['name']?.toString() ?? '',
    email: j['email']?.toString() ?? '',
    role: j['role']?.toString() ?? 'member',
  );

  factory User.fromMap(Map<String, dynamic> j) => User.fromJson(j);

  bool get isAdmin => role == 'admin';
}
