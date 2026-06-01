class PostModel {
  final String id;
  final String senderId;
  final String senderName;
  final String imageUrl;
  final String audioUrl;
  final String caption;
  final DateTime timestamp;

  PostModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.imageUrl,
    required this.audioUrl,
    required this.caption,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'senderName': senderName,
      'imageUrl': imageUrl,
      'audioUrl': audioUrl,
      'caption': caption,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory PostModel.fromMap(Map<String, dynamic> map) {
    return PostModel(
      id: map['id'] ?? '',
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      audioUrl: map['audioUrl'] ?? '',
      caption: map['caption'] ?? '',
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
