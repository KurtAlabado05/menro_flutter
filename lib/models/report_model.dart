import 'package:cloud_firestore/cloud_firestore.dart';

class ReportModel {
  final String id;
  final String title;
  final String description;
  final String category;
  final String location;
  final String? barangay;
  final String? sitio;
  final String? landmark;
  final double? latitude;
  final double? longitude;
  final String status;
  final String? imageUrl;
  final List<String> imageUrls;
  final String submittedBy;
  final String submittedByName;
  final String? submittedByContact;
  final bool isAnonymous;
  final DateTime submittedAt;
  final int upvotes;
  final int commentCount;
  final int severity;
  final List<ReportStatusUpdate> statusHistory;

  ReportModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.location,
    this.barangay,
    this.sitio,
    this.landmark,
    this.latitude,
    this.longitude,
    this.status = 'pending',
    this.imageUrl,
    this.imageUrls = const [],
    required this.submittedBy,
    required this.submittedByName,
    this.submittedByContact,
    this.isAnonymous = false,
    required this.submittedAt,
    this.upvotes = 0,
    this.commentCount = 0,
    this.severity = 1,
    this.statusHistory = const [],
  });

  factory ReportModel.fromFirestore(Map<String, dynamic> json, String docId) {
    return ReportModel(
      id: docId,
      title: _safeString(json['title'], ''),
      description: _safeString(json['description'], ''),
      category: _safeString(json['category'], ''),
      location: _safeString(json['location'], ''),
      barangay: _safeNullableString(json['barangay']),
      sitio: _safeNullableString(json['sitio']),
      landmark: _safeNullableString(json['landmark']),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      status: _safeString(json['status'], 'pending'),
      imageUrl: _safeNullableString(json['imageUrl']),
      imageUrls: json['imageUrls'] is List
          ? List<String>.from(
              (json['imageUrls'] as List).map((e) => e.toString()),
            )
          : [],
      submittedBy: _safeString(json['submittedBy'], ''),
      submittedByName: _safeString(json['submittedByName'], 'Anonymous'),
      submittedByContact: _safeNullableString(json['submittedByContact']),
      isAnonymous: json['isAnonymous'] ?? false,
      submittedAt: json['submittedAt'] is Timestamp
          ? (json['submittedAt'] as Timestamp).toDate()
          : json['submittedAt'] != null
          ? DateTime.tryParse(json['submittedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      upvotes: json['upvotes'] ?? 0,
      commentCount: json['commentCount'] ?? 0,
      severity: json['severity'] ?? 1,
      statusHistory:
          (json['statusHistory'] as List?)
              ?.map(
                (e) => ReportStatusUpdate.fromJson(
                  e is Map<String, dynamic>
                      ? e
                      : Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList() ??
          [],
    );
  }

  factory ReportModel.fromJson(Map<String, dynamic> json) {
    return ReportModel(
      id: _safeString(json['id'], ''),
      title: _safeString(json['title'], ''),
      description: _safeString(json['description'], ''),
      category: _safeString(json['category'], ''),
      location: _safeString(json['location'], ''),
      barangay: _safeNullableString(json['barangay']), // Added missing parsing
      sitio: _safeNullableString(json['sitio']), // Added missing parsing
      landmark: _safeNullableString(json['landmark']), // Added missing parsing
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      status: _safeString(json['status'], 'pending'),
      imageUrl: _safeNullableString(json['imageUrl']),
      imageUrls: json['imageUrls'] is List
          ? List<String>.from(
              (json['imageUrls'] as List).map((e) => e.toString()),
            )
          : [],
      submittedBy: _safeString(json['submittedBy'], ''),
      submittedByName: _safeString(json['submittedByName'], 'Anonymous'),
      submittedByContact: _safeNullableString(json['submittedByContact']),
      isAnonymous: json['isAnonymous'] ?? false,
      submittedAt: json['submittedAt'] != null
          ? DateTime.tryParse(json['submittedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      upvotes: json['upvotes'] ?? 0,
      commentCount: json['commentCount'] ?? 0,
      severity: json['severity'] ?? 1,
      statusHistory:
          (json['statusHistory'] as List?)
              ?.map(
                (e) => ReportStatusUpdate.fromJson(
                  e is Map<String, dynamic>
                      ? e
                      : Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'category': category,
    'location': location,
    'barangay': barangay,
    'sitio': sitio,
    'landmark': landmark,
    'latitude': latitude,
    'longitude': longitude,
    'status': status,
    'imageUrl': imageUrl,
    'imageUrls': imageUrls,
    'submittedBy': submittedBy,
    'submittedByName': submittedByName,
    'submittedByContact': submittedByContact,
    'isAnonymous': isAnonymous,
    'submittedAt': submittedAt.toIso8601String(),
    'upvotes': upvotes,
    'commentCount': commentCount,
    'severity': severity,
    'statusHistory': statusHistory.map((e) => e.toJson()).toList(),
  };

  Map<String, dynamic> toFirestore() => {
    'title': title,
    'description': description,
    'category': category,
    'location': location,
    'barangay': barangay,
    'sitio': sitio,
    'landmark': landmark,
    'latitude': latitude,
    'longitude': longitude,
    'status': status,
    'imageUrl': imageUrl,
    'imageUrls': imageUrls,
    'submittedBy': submittedBy,
    'submittedByName': submittedByName,
    'submittedByContact': submittedByContact,
    'isAnonymous': isAnonymous,
    'submittedAt': FieldValue.serverTimestamp(),
    'severity': severity,
    'statusHistory': statusHistory
        .map(
          (e) => {
            'status': e.status,
            'message': e.message,
            'timestamp': e.timestamp.toIso8601String(),
            'updatedBy': e.updatedBy,
          },
        )
        .toList(),
  };

  ReportModel copyWith({
    String? status,
    int? upvotes,
    int? commentCount,
    List<ReportStatusUpdate>? statusHistory,
  }) {
    return ReportModel(
      id: id,
      title: title,
      description: description,
      category: category,
      location: location,
      barangay: barangay,
      sitio: sitio,
      landmark: landmark,
      latitude: latitude,
      longitude: longitude,
      status: status ?? this.status,
      imageUrl: imageUrl,
      imageUrls: imageUrls,
      submittedBy: submittedBy,
      submittedByName: submittedByName,
      submittedByContact: submittedByContact,
      isAnonymous: isAnonymous,
      submittedAt: submittedAt,
      upvotes: upvotes ?? this.upvotes,
      commentCount: commentCount ?? this.commentCount,
      severity: severity,
      statusHistory: statusHistory ?? this.statusHistory,
    );
  }
}

class ReportStatusUpdate {
  final String status;
  final String message;
  final DateTime timestamp;
  final String? updatedBy;

  ReportStatusUpdate({
    required this.status,
    required this.message,
    required this.timestamp,
    this.updatedBy,
  });

  factory ReportStatusUpdate.fromJson(Map<String, dynamic> json) {
    return ReportStatusUpdate(
      status: _safeString(json['status'], ''),
      message: _safeString(json['message'], ''),
      timestamp: json['timestamp'] is Timestamp
          ? (json['timestamp'] as Timestamp).toDate()
          : json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedBy: _safeNullableString(json['updatedBy']),
    );
  }

  Map<String, dynamic> toJson() => {
    'status': status,
    'message': message,
    'timestamp': timestamp.toIso8601String(),
    'updatedBy': updatedBy,
  };
}

// Global Help Clean-up Parsers to stop Map parsing bugs
String _safeString(dynamic val, String fallback) {
  if (val == null) return fallback;
  if (val is Map) {
    return val['name']?.toString() ??
        val['display_name']?.toString() ??
        val['formatted_address']?.toString() ??
        val.toString();
  }
  return val.toString();
}

String? _safeNullableString(dynamic val) {
  if (val == null) return null;
  if (val is Map) {
    return val['name']?.toString() ??
        val['display_name']?.toString() ??
        val['formatted_address']?.toString() ??
        val.toString();
  }
  return val.toString();
}
