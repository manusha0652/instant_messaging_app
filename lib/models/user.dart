class User {
  final int? id;
  final String name;
  final String phone;
  final String? bio;
  final String? profilePicture;
  final String? pinHash;
  final int createdAt;

  User({
    this.id,
    required this.name,
    required this.phone,
    this.bio,
    this.profilePicture,
    this.pinHash,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'bio': bio,
      'profilePicture': profilePicture,
      'pinHash': pinHash,
      'createdAt': createdAt,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      name: map['name'],
      phone: map['phone'],
      bio: map['bio'],
      profilePicture: map['profilePicture'],
      pinHash: map['pinHash'],
      createdAt: map['createdAt'],
    );
  }
}
