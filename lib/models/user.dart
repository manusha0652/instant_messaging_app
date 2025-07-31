class User {
  final int? id;
  final String name;
  final String phone;
  final String? bio;
  final String? profilePicture;
  final String? pinHash;
  final String? socketId;
  final bool isOnline;
  final DateTime? lastSeen;
  final DateTime createdAt;

  User({
    this.id,
    required this.name,
    required this.phone,
    this.bio,
    this.profilePicture,
    this.pinHash,
    this.socketId,
    this.isOnline = false,
    this.lastSeen,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'phone': phone,
      'bio': bio,
      'profilePicture': profilePicture,
      'pinHash': pinHash,
      'socketId': socketId,
      'isOnline': isOnline ? 1 : 0,
      'lastSeen': lastSeen?.millisecondsSinceEpoch,
      'createdAt': createdAt.millisecondsSinceEpoch,
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
      socketId: map['socketId'],
      isOnline: map['isOnline'] == 1,
      lastSeen: map['lastSeen'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['lastSeen'])
          : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
    );
  }

  User copyWith({
    int? id,
    String? name,
    String? phone,
    String? bio,
    String? profilePicture,
    String? pinHash,
    String? socketId,
    bool? isOnline,
    DateTime? lastSeen,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      bio: bio ?? this.bio,
      profilePicture: profilePicture ?? this.profilePicture,
      pinHash: pinHash ?? this.pinHash,
      socketId: socketId ?? this.socketId,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'User{id: $id, name: $name, phone: $phone, bio: $bio, socketId: $socketId, isOnline: $isOnline}';
  }
}
