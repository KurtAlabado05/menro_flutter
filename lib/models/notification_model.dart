import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType { reportUpdate, projectUpdate, comment, mention, system, badgeEarned }

class NotificationModel {
  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final DateTime timestamp;
  final bool isRead;
  final String? relatedId;
  final String? imageUrl;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.relatedId,
    this.imageUrl,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'],
      title: json['title'],
      body: json['body'],
      type: NotificationType.values.byName(json['type']),
      timestamp: DateTime.parse(json['timestamp']),
      isRead: json['isRead'] ?? false,
      relatedId: json['relatedId'],
      imageUrl: json['imageUrl'],
    );
  }

  factory NotificationModel.fromFirestore(Map<String, dynamic> data, String id) {
    Timestamp? timestamp = data['timestamp'];
    DateTime dt = timestamp?.toDate() ?? DateTime.now();

    return NotificationModel(
      id: id,
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      type: NotificationType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => NotificationType.system,
      ),
      timestamp: dt,
      isRead: data['isRead'] ?? false,
      relatedId: data['relatedId'],
      imageUrl: data['imageUrl'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'type': type.name,
        'timestamp': timestamp.toIso8601String(),
        'isRead': isRead,
        'relatedId': relatedId,
        'imageUrl': imageUrl,
      };

  NotificationModel copyWith({bool? isRead}) {
    return NotificationModel(
      id: id,
      title: title,
      body: body,
      type: type,
      timestamp: timestamp,
      isRead: isRead ?? this.isRead,
      relatedId: relatedId,
      imageUrl: imageUrl,
    );
  }
}

