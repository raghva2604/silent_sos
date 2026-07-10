/// Recipient model for email recipients
class Recipient {
  final String name;
  final String? email;
  final String? phone;
  Recipient({required this.name, this.email, this.phone});
  Map<String, dynamic> toJson() =>
      {'name': name, 'email': email, 'phone': phone};
  static Recipient fromJson(Map<String, dynamic> j) => Recipient(
        name: j['name'] ?? '',
        email: j['email'],
        phone: j['phone'],
      );
}
