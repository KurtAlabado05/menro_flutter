class CommentModel {
  final String id;
  final String feedId;
  final String authorName;
  final String message;
  final DateTime postedAt;

  CommentModel({
    required this.id,
    required this.feedId,
    required this.authorName,
    required this.message,
    required this.postedAt,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    return CommentModel(
      id: json['id'],
      feedId: json['feedId'],
      authorName: json['authorName'],
      message: json['message'],
      postedAt: DateTime.parse(json['postedAt']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'feedId': feedId,
        'authorName': authorName,
        'message': message,
        'postedAt': postedAt.toIso8601String(),
      };
}