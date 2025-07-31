class Message {
  final int? id;
  final int sessionId;
  final String content;
  final bool isFromMe;
  final DateTime timestamp;
  final String messageType;
  final bool isRead;
  final bool isDelivered;
  final bool isSent;

  Message({
    this.id,
    required this.sessionId,
    required this.content,
    required this.isFromMe,
    required this.timestamp,
    this.messageType = 'text',
    this.isRead = false,
    this.isDelivered = false,
    this.isSent = true,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'sessionId': sessionId,
      'content': content,
      'isFromMe': isFromMe ? 1 : 0,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'messageType': messageType,
      'isRead': isRead ? 1 : 0,
      'isDelivered': isDelivered ? 1 : 0,
      'isSent': isSent ? 1 : 0,
    };
  }

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'],
      sessionId: map['sessionId'],
      content: map['content'],
      isFromMe: map['isFromMe'] == 1,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
      messageType: map['messageType'] ?? 'text',
      isRead: map['isRead'] == 1,
      isDelivered: map['isDelivered'] == 1,
      isSent: map['isSent'] == 1,
    );
  }

  Message copyWith({
    int? id,
    int? sessionId,
    String? content,
    bool? isFromMe,
    DateTime? timestamp,
    String? messageType,
    bool? isRead,
    bool? isDelivered,
    bool? isSent,
  }) {
    return Message(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      content: content ?? this.content,
      isFromMe: isFromMe ?? this.isFromMe,
      timestamp: timestamp ?? this.timestamp,
      messageType: messageType ?? this.messageType,
      isRead: isRead ?? this.isRead,
      isDelivered: isDelivered ?? this.isDelivered,
      isSent: isSent ?? this.isSent,
    );
  }
}
