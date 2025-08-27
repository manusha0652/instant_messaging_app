class ChatSession {
  final int? id;
  final int userId;
  final String contactPhone;
  final String contactName;
  final String? contactAvatar;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCount;
  final bool isActive;

  ChatSession({
    this.id,
    required this.userId,
    required this.contactPhone,
    required this.contactName,
    this.contactAvatar,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCount = 0,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'userId': userId,
      'contactPhone': contactPhone,
      'contactName': contactName,
      'contactAvatar': contactAvatar,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime?.millisecondsSinceEpoch,
      'unreadCount': unreadCount,
      'isActive': isActive ? 1 : 0,
    };
  }

  factory ChatSession.fromMap(Map<String, dynamic> map) {
    return ChatSession(
      id: map['id'],
      userId: map['userId'],
      contactPhone: map['contactPhone'],
      contactName: map['contactName'],
      contactAvatar: map['contactAvatar'],
      lastMessage: map['lastMessage'],
      lastMessageTime: map['lastMessageTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['lastMessageTime'])
          : null,
      unreadCount: map['unreadCount'] ?? 0,
      isActive: map['isActive'] == 1,
    );
  }

  ChatSession copyWith({
    int? id,
    int? userId,
    String? contactPhone,
    String? contactName,
    String? contactAvatar,
    String? lastMessage,
    DateTime? lastMessageTime,
    int? unreadCount,
    bool? isActive,
  }) {
    return ChatSession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      contactPhone: contactPhone ?? this.contactPhone,
      contactName: contactName ?? this.contactName,
      contactAvatar: contactAvatar ?? this.contactAvatar,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
      isActive: isActive ?? this.isActive,
    );
  }
}
