class MessageModel {
  final int? id;
  final int sessionId;
  final String content;
  final bool isFromMe;
  final DateTime timestamp;
  final String? messageType; // text, image, file
  final String? attachmentPath;

  MessageModel({
    this.id,
    required this.sessionId,
    required this.content,
    required this.isFromMe,
    required this.timestamp,
    this.messageType = 'text',
    this.attachmentPath,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sessionId': sessionId,
      'content': content,
      'isFromMe': isFromMe ? 1 : 0,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'messageType': messageType,
      'attachmentPath': attachmentPath,
    };
  }

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      id: map['id'],
      sessionId: map['sessionId'],
      content: map['content'],
      isFromMe: map['isFromMe'] == 1,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
      messageType: map['messageType'] ?? 'text',
      attachmentPath: map['attachmentPath'],
    );
  }

  MessageModel copyWith({
    int? id,
    int? sessionId,
    String? content,
    bool? isFromMe,
    DateTime? timestamp,
    String? messageType,
    String? attachmentPath,
  }) {
    return MessageModel(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      content: content ?? this.content,
      isFromMe: isFromMe ?? this.isFromMe,
      timestamp: timestamp ?? this.timestamp,
      messageType: messageType ?? this.messageType,
      attachmentPath: attachmentPath ?? this.attachmentPath,
    );
  }
}
