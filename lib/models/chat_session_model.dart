class ChatSessionModel {
  final int? id;
  final String peerName;
  final String? peerAvatar;
  final String? peerQrData;
  final DateTime startTime;
  final DateTime? endTime;
  final bool isActive;
  final String? lastMessage;
  final DateTime? lastMessageTime;

  ChatSessionModel({
    this.id,
    required this.peerName,
    this.peerAvatar,
    this.peerQrData,
    required this.startTime,
    this.endTime,
    required this.isActive,
    this.lastMessage,
    this.lastMessageTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'peerName': peerName,
      'peerAvatar': peerAvatar,
      'peerQrData': peerQrData,
      'startTime': startTime.millisecondsSinceEpoch,
      'endTime': endTime?.millisecondsSinceEpoch,
      'isActive': isActive ? 1 : 0,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime?.millisecondsSinceEpoch,
    };
  }

  factory ChatSessionModel.fromMap(Map<String, dynamic> map) {
    return ChatSessionModel(
      id: map['id'],
      peerName: map['peerName'],
      peerAvatar: map['peerAvatar'],
      peerQrData: map['peerQrData'],
      startTime: DateTime.fromMillisecondsSinceEpoch(map['startTime']),
      endTime: map['endTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['endTime'])
          : null,
      isActive: map['isActive'] == 1,
      lastMessage: map['lastMessage'],
      lastMessageTime: map['lastMessageTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['lastMessageTime'])
          : null,
    );
  }

  ChatSessionModel copyWith({
    int? id,
    String? peerName,
    String? peerAvatar,
    String? peerQrData,
    DateTime? startTime,
    DateTime? endTime,
    bool? isActive,
    String? lastMessage,
    DateTime? lastMessageTime,
  }) {
    return ChatSessionModel(
      id: id ?? this.id,
      peerName: peerName ?? this.peerName,
      peerAvatar: peerAvatar ?? this.peerAvatar,
      peerQrData: peerQrData ?? this.peerQrData,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isActive: isActive ?? this.isActive,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
    );
  }

  String get timeAgoString {
    final now = DateTime.now();
    final difference = now.difference(lastMessageTime ?? startTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}
