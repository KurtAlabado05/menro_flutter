import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/feed_model.dart';
import '../models/comment_model.dart';

class FeedProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<FeedModel> _feed = [];
  List<FeedModel> _filteredFeed = [];
  bool _isLoading = false;
  String _activeFilter = 'All';

  final Map<String, List<CommentModel>> _comments = {};
  final Set<String> _commentsLoading = {};
  final Set<String> _upvotedReports = {};

  List<FeedModel> get feed => _filteredFeed;
  bool get isLoading => _isLoading;
  String get activeFilter => _activeFilter;

  List<CommentModel> getComments(String feedId) => _comments[feedId] ?? [];
  bool isCommentsLoading(String feedId) => _commentsLoading.contains(feedId);
  bool hasUpvoted(String reportId) => _upvotedReports.contains(reportId);

  // ─── Load Feed from Firestore ─────────────────────────────────────────────

  Future<void> loadFeed() async {
    _isLoading = true;
    notifyListeners();

    try {
      final snapshot = await _db
          .collection('feed')
          .orderBy('postedAt', descending: true)
          .get();

      _feed = snapshot.docs.map((doc) {
        return FeedModel.fromFirestore(doc.data(), doc.id);
      }).toList();

      final currentUid = _auth.currentUser?.uid;
      if (currentUid != null) {
        await _loadUserLikes(currentUid);
      }

      _applyFilter();
    } catch (e) {
      debugPrint('FeedProvider.loadFeed error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadUserLikes(String uid) async {
    try {
      final likesSnapshot = await _db
          .collection('users')
          .doc(uid)
          .collection('likes')
          .get();

      final likedIds = likesSnapshot.docs.map((d) => d.id).toSet();

      _feed = _feed.map((item) {
        return item.copyWith(isLiked: likedIds.contains(item.id));
      }).toList();
    } catch (e) {
      debugPrint('FeedProvider._loadUserLikes error: $e');
    }
  }

  // ─── Filters ──────────────────────────────────────────────────────────────

  void setFilter(String filter) {
    _activeFilter = filter;
    _applyFilter();
    notifyListeners();
  }

  void _applyFilter() {
    switch (_activeFilter) {
      case 'Reports':
        _filteredFeed = _feed
            .where((f) => f.type == FeedItemType.report)
            .toList();
        break;
      case 'Projects':
        _filteredFeed = _feed
            .where((f) => f.type == FeedItemType.projectUpdate)
            .toList();
        break;
      case 'Completed':
        _filteredFeed = _feed
            .where((f) => f.status == 'completed')
            .toList();
        break;
      case 'Verified':
        _filteredFeed = _feed
            .where((f) => f.isVerified)
            .toList();
        break;
      default:
        _filteredFeed = List.from(_feed);
    }
  }

  // ─── Likes ────────────────────────────────────────────────────────────────

  Future<void> toggleLike(String feedId) async {
    final index = _feed.indexWhere((f) => f.id == feedId);
    if (index == -1) return;

    final item = _feed[index];
    final newIsLiked = !item.isLiked;
    final newCount = newIsLiked ? item.likeCount + 1 : item.likeCount - 1;

    // Optimistic UI update
    _feed[index] = item.copyWith(isLiked: newIsLiked, likeCount: newCount);
    _applyFilter();
    notifyListeners();

    try {
      final uid = _auth.currentUser?.uid;
      final feedRef = _db.collection('feed').doc(feedId);
      final batch = _db.batch();

      batch.update(feedRef, {'likeCount': newCount});

      if (uid != null) {
        final likeRef = _db
            .collection('users')
            .doc(uid)
            .collection('likes')
            .doc(feedId);
        if (newIsLiked) {
          batch.set(likeRef, {'likedAt': FieldValue.serverTimestamp()});
        } else {
          batch.delete(likeRef);
        }
      }

      await batch.commit();
    } catch (e) {
      // Rollback on failure
      _feed[index] = item;
      _applyFilter();
      notifyListeners();
      debugPrint('FeedProvider.toggleLike error: $e');
    }
  }

  void syncReportLike(String reportId, int newCount, {bool isLiked = true}) {
    final index = _feed.indexWhere((f) => f.relatedId == reportId);
    if (index != -1) {
      _feed[index] = _feed[index].copyWith(
        likeCount: newCount,
        isLiked: isLiked,
      );
      _applyFilter();
      notifyListeners();
    }
  }

  // ─── Comments ─────────────────────────────────────────────────────────────

  Future<void> loadComments(String feedId) async {
    _commentsLoading.add(feedId);
    notifyListeners();

    try {
      final snapshot = await _db
          .collection('feed')
          .doc(feedId)
          .collection('comments')
          .orderBy('postedAt', descending: false)
          .get();

      _comments[feedId] = snapshot.docs.map((doc) {
        final data = doc.data();
        return CommentModel(
          id: doc.id,
          feedId: feedId,
          authorName: data['authorName'] ?? 'Anonymous',
          message: data['message'] ?? '',
          postedAt: data['postedAt'] != null
              ? (data['postedAt'] as Timestamp).toDate()
              : DateTime.now(),
        );
      }).toList();
    } catch (e) {
      debugPrint('FeedProvider.loadComments error: $e');
    } finally {
      _commentsLoading.remove(feedId);
      notifyListeners();
    }
  }

  Future<void> addComment(String feedId, String message) async {
    final user = _auth.currentUser;
    final authorName = user?.displayName ?? 'Anonymous';

    try {
      final commentRef = _db
          .collection('feed')
          .doc(feedId)
          .collection('comments')
          .doc();

      final newComment = CommentModel(
        id: commentRef.id,
        feedId: feedId,
        authorName: authorName,
        message: message,
        postedAt: DateTime.now(),
      );

      // Optimistic UI update
      _comments.putIfAbsent(feedId, () => []).add(newComment);
      final index = _feed.indexWhere((f) => f.id == feedId);
      if (index != -1) {
        _feed[index] = _feed[index].copyWith(
          commentCount: _feed[index].commentCount + 1,
        );
        _applyFilter();
      }
      notifyListeners();

      // Write to Firestore
      await commentRef.set({
        'authorName': authorName,
        'message': message,
        'postedAt': FieldValue.serverTimestamp(),
      });

      await _db.collection('feed').doc(feedId).update({
        'commentCount': FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint('FeedProvider.addComment error: $e');
    }
  }
}