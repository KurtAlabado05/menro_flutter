import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/project_model.dart';

class ProjectProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  List<ProjectModel> _projects = [];
  ProjectModel? _selectedProject;
  bool _isLoading = false;
  String? _error;

  // Kept for backwards-compatibility with existing screens
  List<ProjectModel> get projects => _projects;
  List<ProjectModel> get myProjects => _projects;

  ProjectModel? get selectedProject => _selectedProject;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // ─── Load Projects ────────────────────────────────────────────────────────

  Future<void> loadProjects() async {
    if (_isLoading) return; // avoid overlapping loads

    _isLoading = true;
    _error = null;
    try {
      final snapshot = await _db
          .collection('projects')
          .orderBy('createdAt', descending: true)
          .get();

      final loaded = <ProjectModel>[];
      for (final doc in snapshot.docs) {
        try {
          loaded.add(ProjectModel.fromFirestore(doc.data(), doc.id));
        } catch (e) {
          debugPrint('❌ Parse Project Error docId=${doc.id}: $e');
        }
      }

      _projects = loaded;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ Load Projects Error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadProjectById(String id) async {
    _isLoading = true;
    notifyListeners();
    try {
      final doc = await _db.collection('projects').doc(id).get();
      if (doc.exists && doc.data() != null) {
        _selectedProject = ProjectModel.fromFirestore(doc.data()!, doc.id);
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ Load Project By ID Error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── Create Project ──────────────────────────────────────────────────────

  Future<void> createProject({
    required String title,
    required String description,
    required String location,
    required String category,
    required String createdBy,
    required String createdByName,
    required String targetOutcome,
    required DateTime targetCompletionDate,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final docRef = _db.collection('projects').doc();
      final now = DateTime.now();

      final project = ProjectModel(
        id: docRef.id,
        title: title,
        description: description,
        location: location,
        category: category,
        status: 'pending',
        createdBy: createdBy,
        createdByName: createdByName,
        createdAt: now,
        participantCount: 0,
        participants: [],
        targetOutcome: targetOutcome,
        targetCompletionDate: targetCompletionDate,
      );

      await docRef.set(project.toFirestore());
      _projects.insert(0, project);
      debugPrint('✅ Project created: ${docRef.id}');
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ Create Project Error: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── Participation Logic ──────────────────────────────────────────────────

  Future<void> joinProject(String projectId, String userId) async {
    final ref = _db.collection('projects').doc(projectId);
    await ref.update({
      'participants': FieldValue.arrayUnion([userId]),
      'participantCount': FieldValue.increment(1),
    });
    await loadProjectById(projectId);
  }

  Future<void> leaveProject(String projectId, String userId) async {
    final ref = _db.collection('projects').doc(projectId);
    await ref.update({
      'participants': FieldValue.arrayRemove([userId]),
      'participantCount': FieldValue.increment(-1),
    });
    await loadProjectById(projectId);
  }
}
