import 'package:cloud_firestore/cloud_firestore.dart';

class ProjectModel {
  final String id;
  final String title;
  final String description;
  final String location;
  final String category;
  final String status;
  final String createdBy; // Ensure this is defined
  final String createdByName;
  final DateTime createdAt; // Ensure this is defined
  final int participantCount;
  final List<String> participants;
  final String targetOutcome;
  final DateTime targetCompletionDate;

  final double? latitude;
  final double? longitude;

  ProjectModel({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.category,
    required this.status,
    required this.createdBy, // Added to constructor
    required this.createdByName,
    required this.createdAt, // Added to constructor
    required this.participantCount,
    required this.participants,
    required this.targetOutcome,
    required this.targetCompletionDate,
    this.latitude,
    this.longitude,
  });

  factory ProjectModel.fromFirestore(Map<String, dynamic> data, String id) {
    DateTime parseDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      if (v is String) {
        try {
          return DateTime.parse(v);
        } catch (_) {
          return DateTime.now();
        }
      }
      return DateTime.now();
    }

    final participantsRaw = data['participants'];
    final participants = participantsRaw is Iterable
        ? participantsRaw
              .map((e) => e.toString())
              .where((e) => e.isNotEmpty)
              .toList()
        : <String>[];

    final participantCountRaw = data['participantCount'];
    final participantCount = participantCountRaw is int
        ? participantCountRaw
        : (participantCountRaw is num ? participantCountRaw.toInt() : 0);

    return ProjectModel(
      id: id,
      title: (data['title'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      location: (data['locationName'] ?? data['location'] ?? '').toString(),
      category: (data['category'] ?? '').toString(),
      status: (data['status'] ?? 'pending').toString(),
      createdBy: (data['createdBy'] ?? '').toString(),
      createdByName: (data['createdByName'] ?? '').toString(),
      createdAt: parseDate(data['createdAt']),
      participantCount: participantCount,
      participants: participants,
      targetOutcome: (data['targetOutcome'] ?? 'N/A').toString(),
      targetCompletionDate: parseDate(data['targetCompletionDate']),
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
    );
  }

  // This fixes the "method 'toFirestore' isn't defined" error
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'locationName': location,
      'category': category,
      'status': status,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'createdAt': Timestamp.fromDate(createdAt),
      'participantCount': participantCount,
      'participants': participants,
      'targetOutcome': targetOutcome,
      'targetCompletionDate': Timestamp.fromDate(targetCompletionDate),
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}
