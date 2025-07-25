class UserModel {
  final int? id;
  final String name;
  final String? profilePicturePath;
  final String pinHash;
  final bool biometricEnabled;
  final DateTime createdAt;

  UserModel({
    this.id,
    required this.name,
    this.profilePicturePath,
    required this.pinHash,
    required this.biometricEnabled,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'profilePicturePath': profilePicturePath,
      'pinHash': pinHash,
      'biometricEnabled': biometricEnabled ? 1 : 0,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'],
      name: map['name'],
      profilePicturePath: map['profilePicturePath'],
      pinHash: map['pinHash'],
      biometricEnabled: map['biometricEnabled'] == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
    );
  }

  UserModel copyWith({
    int? id,
    String? name,
    String? profilePicturePath,
    String? pinHash,
    bool? biometricEnabled,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      profilePicturePath: profilePicturePath ?? this.profilePicturePath,
      pinHash: pinHash ?? this.pinHash,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
