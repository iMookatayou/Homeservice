class User {
  final String id;
  final String name;
  final String email;

  const User({required this.id, required this.name, required this.email});

  factory User.fromJson(Map<String, dynamic> j) => User(
    id: '${j['id']}',
    name: (j['name'] ?? '').toString(),
    email: (j['email'] ?? '').toString(),
  );

  // ถ้าคุณมี fromMap อยู่แล้ว ให้ใช้ชื่อเดียวกันทุกที่เพื่อเลี่ยงสับสน
  factory User.fromMap(Map<String, dynamic> j) => User.fromJson(j);
}
