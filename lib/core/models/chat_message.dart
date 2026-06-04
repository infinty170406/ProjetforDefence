class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? actionType; // For actionable messages

  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.actionType,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] ?? DateTime.now().toIso8601String(),
      text: json['text'] ?? '',
      isUser: json['isUser'] ?? false,
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp']) 
          : DateTime.now(),
      actionType: json['actionType'],
    );
  }
}
