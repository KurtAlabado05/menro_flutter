import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/report_model.dart';

class ReportProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<ReportModel> _reports = [];
  List<ReportModel> _myReports = [];
  ReportModel? _selectedReport;
  bool _isLoading = false;
  String? _error;
  final Set<String> _upvotedByMe = {};

  List<ReportModel> get reports => _reports;
  List<ReportModel> get myReports => _myReports;
  ReportModel? get selectedReport => _selectedReport;
  bool get isLoading => _isLoading;
  String? get error => _error;

  bool hasUpvoted(String reportId) => _upvotedByMe.contains(reportId);

  // ─── Load All Reports ─────────────────────────────────────────────────────

  Future<void> loadReports() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final snapshot = await _db
          .collection('reports')
          .orderBy('submittedAt', descending: true)
          .get();

      _reports = snapshot.docs
          .map((doc) => ReportModel.fromFirestore(doc.data(), doc.id))
          .toList();

      await _loadMyUpvotes();
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ loadReports error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── Load My Reports ──────────────────────────────────────────────────────

  Future<void> loadMyReports(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final snapshot = await _db
          .collection('reports')
          .where('submittedBy', isEqualTo: userId)
          .orderBy('submittedAt', descending: true)
          .get();

      _myReports = snapshot.docs
          .map((doc) => ReportModel.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ loadMyReports error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── Load Report By ID ────────────────────────────────────────────────────

  Future<void> loadReportById(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final doc = await _db.collection('reports').doc(id).get();
      if (doc.exists && doc.data() != null) {
        _selectedReport = ReportModel.fromFirestore(doc.data()!, doc.id);
      } else {
        _error = 'Report not found';
        _selectedReport = null;
      }
    } catch (e) {
      _error = e.toString();
      _selectedReport = null;
      debugPrint('❌ loadReportById error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── Submit Report ────────────────────────────────────────────────────────

  Future<ReportModel> submitReport(ReportModel report) async {
    _isLoading = true;
    notifyListeners();

    try {
      debugPrint('📝 Submitting report to Firestore...');

      // Save to reports collection
      final docRef = _db.collection('reports').doc();
      await docRef.set(report.toFirestore());
      debugPrint('✅ Report saved: ${docRef.id}');


      final newReport = ReportModel(
        id: docRef.id,
        title: report.title,
        description: report.description,
        category: report.category,
        location: report.location,
        barangay: report.barangay,
        sitio: report.sitio,
        landmark: report.landmark,
        latitude: report.latitude,
        longitude: report.longitude,
        status: report.status,
        imageUrl: report.imageUrl,
        imageUrls: report.imageUrls,
        submittedBy: report.submittedBy,
        submittedByName: report.submittedByName,
        submittedByContact: report.submittedByContact,
        isAnonymous: report.isAnonymous,
        submittedAt: DateTime.now(),
        upvotes: 0,
        commentCount: 0,
        severity: report.severity,
        statusHistory: report.statusHistory,
      );

      _reports.insert(0, newReport);
      _myReports.insert(0, newReport);
      return newReport;

    } catch (e, stack) {
      debugPrint('❌ submitReport FAILED: $e');
      debugPrint('❌ Stack: $stack');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── Toggle Upvote ────────────────────────────────────────────────────────

  Future<int> toggleUpvoteReport(String reportId) async {
    final uid = _auth.currentUser?.uid;
    final hasVoted = _upvotedByMe.contains(reportId);

    // Optimistic update
    final idx = _reports.indexWhere((r) => r.id == reportId);
    final myIdx = _myReports.indexWhere((r) => r.id == reportId);

    if (idx != -1) {
      _reports[idx] = _reports[idx].copyWith(
        upvotes: hasVoted ? _reports[idx].upvotes - 1 : _reports[idx].upvotes + 1,
      );
    }
    if (myIdx != -1) {
      _myReports[myIdx] = _myReports[myIdx].copyWith(
        upvotes: hasVoted ? _myReports[myIdx].upvotes - 1 : _myReports[myIdx].upvotes + 1,
      );
    }
    if (_selectedReport?.id == reportId) {
      _selectedReport = _selectedReport!.copyWith(
        upvotes: hasVoted ? _selectedReport!.upvotes - 1 : _selectedReport!.upvotes + 1,
      );
    }

    if (hasVoted) {
      _upvotedByMe.remove(reportId);
    } else {
      _upvotedByMe.add(reportId);
    }
    notifyListeners();

    try {
      final reportRef = _db.collection('reports').doc(reportId);
      final batch = _db.batch();

      batch.update(reportRef, {
        'upvotes': FieldValue.increment(hasVoted ? -1 : 1),
      });

      if (uid != null) {
        final upvoteRef = reportRef.collection('upvotes').doc(uid);
        if (hasVoted) {
          batch.delete(upvoteRef);
        } else {
          batch.set(upvoteRef, {'upvotedAt': FieldValue.serverTimestamp()});
        }

        // Sync feed entry likeCount too
        final feedRef = _db.collection('feed').doc('feed_$reportId');
        batch.update(feedRef, {
          'likeCount': FieldValue.increment(hasVoted ? -1 : 1),
        });
      }

      await batch.commit();

      final current = idx != -1 ? _reports[idx] : _selectedReport;
      return current?.upvotes ?? 0;
    } catch (e) {
      // Rollback
      if (hasVoted) {
        _upvotedByMe.add(reportId);
      } else {
        _upvotedByMe.remove(reportId);
      }
      await loadReports();
      debugPrint('❌ toggleUpvote error: $e');
      return 0;
    }
  }

  // ─── Load User Upvotes ────────────────────────────────────────────────────

  Future<void> _loadMyUpvotes() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      for (final report in _reports) {
        final doc = await _db
            .collection('reports')
            .doc(report.id)
            .collection('upvotes')
            .doc(uid)
            .get();
        if (doc.exists) _upvotedByMe.add(report.id);
      }
    } catch (e) {
      debugPrint('❌ _loadMyUpvotes error: $e');
    }
  }
}