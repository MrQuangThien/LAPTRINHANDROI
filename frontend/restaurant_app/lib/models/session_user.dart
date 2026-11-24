class SessionUser {
  const SessionUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
  });
  final int id;
  final String fullName;
  final String email;
  final String role;
  factory SessionUser.fromJson(Map<String, dynamic> json) => SessionUser(
    id: json['id'] as int,
    fullName: json['fullName'] as String,
    email: json['email'] as String,
    role: json['role'] as String,
  );
}
