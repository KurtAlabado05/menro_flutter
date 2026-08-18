import 'package:cloud_firestore/cloud_firestore.dart'; // ✅ ADD THIS

enum FeedItemType { report, projectUpdate }

class FeedModel {
  final String id;
  final FeedItemType type;
  final String title;
  final String description;
  final String authorName;
  final String? authorAvatarUrl;
  final DateTime postedAt;
  final String? imageUrl;
  final List<String> imageUrls;
  final String location;
  final double? latitude;
  final double? longitude;
  final int likeCount;
  final int commentCount;
  final bool isLiked;
  final bool isVerified;
  final String? relatedId;
  final String? status;

  FeedModel({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.authorName,
    this.authorAvatarUrl,
    required this.postedAt,
    this.imageUrl,
    this.imageUrls = const [],
    required this.location,
    this.latitude,
    this.longitude,
    this.likeCount = 0,
    this.commentCount = 0,
    this.isLiked = false,
    this.isVerified = false,
    this.relatedId,
    this.status,
  });

  factory FeedModel.fromFirestore(Map<String, dynamic> json, String docId) {
    return FeedModel(
      id: docId,
      type: FeedItemType.values.byName(json['type'] ?? 'report'),
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      authorName: json['authorName'] ?? 'Anonymous',
      authorAvatarUrl: json['authorAvatarUrl'],

      // ✅ FIXED ONLY THIS PART
      postedAt: json['postedAt'] is Timestamp
          ? (json['postedAt'] as Timestamp).toDate()
          : json['postedAt'] != null
              ? DateTime.tryParse(json['postedAt'].toString()) ?? DateTime.now()
              : DateTime.now(),

      imageUrl: json['imageUrl'],
      imageUrls: List<String>.from(json['imageUrls'] ?? []),
      location: json['location'] ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      likeCount: json['likeCount'] ?? 0,
      commentCount: json['commentCount'] ?? 0,
      isLiked: json['isLiked'] ?? false,
      isVerified: json['isVerified'] ?? false,
      relatedId: json['relatedId'],
      status: json['status'],
    );
  }

  factory FeedModel.fromJson(Map<String, dynamic> json) {
    return FeedModel(
      id: json['id'] ?? '',
      type: FeedItemType.values.byName(json['type'] ?? 'report'),
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      authorName: json['authorName'] ?? 'Anonymous',
      authorAvatarUrl: json['authorAvatarUrl'],
      postedAt: json['postedAt'] != null
          ? DateTime.parse(json['postedAt'])
          : DateTime.now(),
      imageUrl: json['imageUrl'],
      imageUrls: List<String>.from(json['imageUrls'] ?? []),
      location: json['location'] ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      likeCount: json['likeCount'] ?? 0,
      commentCount: json['commentCount'] ?? 0,
      isLiked: json['isLiked'] ?? false,
      isVerified: json['isVerified'] ?? false,
      relatedId: json['relatedId'],
      status: json['status'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'title': title,
        'description': description,
        'authorName': authorName,
        'authorAvatarUrl': authorAvatarUrl,
        'postedAt': postedAt.toIso8601String(),
        'imageUrl': imageUrl,
        'imageUrls': imageUrls,
        'location': location,
        'latitude': latitude,
        'longitude': longitude,
        'likeCount': likeCount,
        'commentCount': commentCount,
        'isLiked': isLiked,
        'isVerified': isVerified,
        'relatedId': relatedId,
        'status': status,
      };

  FeedModel copyWith({
    int? likeCount,
    int? commentCount,
    bool? isLiked,
    bool? isVerified,
  }) {
    return FeedModel(
      id: id,
      type: type,
      title: title,
      description: description,
      authorName: authorName,
      authorAvatarUrl: authorAvatarUrl,
      postedAt: postedAt,
      imageUrl: imageUrl,
      imageUrls: imageUrls,
      location: location,
      latitude: latitude,
      longitude: longitude,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      isLiked: isLiked ?? this.isLiked,
      isVerified: isVerified ?? this.isVerified,
      relatedId: relatedId,
      status: status,
    );
  }
}