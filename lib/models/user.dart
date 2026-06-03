class UserModel {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String role; // 'buyer' or 'admin'
  final String address;
  final String avatar;
  final String postalCode;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.address,
    this.avatar = '',
    this.postalCode = '',
  });

  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? phone,
    String? role,
    String? address,
    String? avatar,
    String? postalCode,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      address: address ?? this.address,
      avatar: avatar ?? this.avatar,
      postalCode: postalCode ?? this.postalCode,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'address': address,
      'avatar': avatar,
      'postalCode': postalCode,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      role: map['role'] ?? 'buyer',
      address: map['address'] ?? '',
      avatar: map['avatar'] ?? '',
      postalCode: map['postalCode'] ?? '',
    );
  }
}
