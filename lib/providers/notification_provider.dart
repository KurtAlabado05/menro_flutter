import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/notification_model.dart';

class NotificationProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  String? _error;

  List<NotificationModel> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  // ─── Load Notifications for Current User ────────────────────────────────

  Future<void> loadNotifications() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      debugPrint('❌ No authenticated user for notifications');
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final snapshot = await _db
          .collection('notifications')
          .where('userId', isEqualTo: uid)
          .orderBy('timestamp', descending: true)
          .get();

      _notifications = snapshot.docs.map((doc) {
        return NotificationModel.fromFirestore(doc.data(), doc.id);
      }).toList();

      debugPrint('✅ Notifications loaded: ${_notifications.length}');
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ loadNotifications error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── Mark as Read ───────────────────────────────────────────────────────

  Future<void> markAsRead(String id) async {
    // Optimistic update
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx != -1) {
      _notifications[idx] = _notifications[idx].copyWith(isRead: true);
      notifyListeners();
    }

    try {
      await _db.collection('notifications').doc(id).update({
        'isRead': true,
      });
      debugPrint('✅ Notification marked as read: $id');
    } catch (e) {
      debugPrint('❌ markAsRead error: $e');
      // Rollback on failure
      if (idx != -1) {
        _notifications[idx] = _notifications[idx].copyWith(isRead: false);
        notifyListeners();
      }
    }
  }

  // ─── Mark All as Read ───────────────────────────────────────────────────

  Future<void> markAllAsRead() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    // Optimistic update
    _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
    notifyListeners();

    try {
      final batch = _db.batch();
      for (final n in _notifications) {
        batch.update(_db.collection('notifications').doc(n.id), {
          'isRead': true,
        });
      }
      await batch.commit();
      debugPrint('✅ All notifications marked as read');
    } catch (e) {
      debugPrint('❌ markAllAsRead error: $e');
      // Rollback
      await loadNotifications();
    }
  }

  // ─── Clear Error ────────────────────────────────────────────────────────

  void clearError() {
    _error = null;
    notifyListeners();
  }
}