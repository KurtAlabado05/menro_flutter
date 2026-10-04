import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class MapDocument {
  const MapDocument(this.id, this.data);

  final String id;
  final Map<String, dynamic> data;
}

class MapRecord {
  const MapRecord({
    required this.id,
    required this.title,
    required this.location,
    required this.latitude,
    required this.longitude,
    required this.type,
    this.status,
  });

  final String id;
  final String title;
  final String location;
  final double latitude;
  final double longitude;
  final String type;
  final String? status;

  static MapRecord? fromDocument(MapDocument document, String type) {
    final data = document.data;
    double? coordinate(Object? value) {
      if (value == null) return null;
      final parsed = value is num
          ? value.toDouble()
          : value is String
          ? double.tryParse(value)
          : null;
      if (parsed == null || !parsed.isFinite) {
        throw const FormatException('Invalid map coordinates');
      }
      return parsed;
    }

    final latitude = coordinate(data['latitude']);
    final longitude = coordinate(data['longitude']);
    if (latitude == null || longitude == null) return null;
    if (latitude.abs() > 90 || longitude.abs() > 180) {
      throw const FormatException('Map coordinates are outside valid ranges');
    }
    final title = data['title']?.toString().trim() ?? '';
    return MapRecord(
      id: document.id,
      title: title.isNotEmpty
          ? title
          : (data['category']?.toString() ?? (type == 'report' ? 'Report' : 'Project')),
      location: (data['locationName'] ?? data['location'] ?? '').toString(),
      latitude: latitude,
      longitude: longitude,
      type: type,
      status: data['status']?.toString(),
    );
  }
}

class MapLayerResult {
  const MapLayerResult({
    this.records = const [],
    this.unmappedCount = 0,
    this.error,
  });

  final List<MapRecord> records;
  final int unmappedCount;
  final String? error;
}

class MapRecordsResult {
  const MapRecordsResult({required this.reports, required this.projects});

  final MapLayerResult reports;
  final MapLayerResult projects;
}

typedef MapDocumentLoader = Future<List<MapDocument>> Function();

class MapRecordsService {
  MapRecordsService({
    MapDocumentLoader? reportsLoader,
    MapDocumentLoader? projectsLoader,
  }) : _reportsLoader = reportsLoader ?? _loadReports,
       _projectsLoader = projectsLoader ?? _loadProjects;

  final MapDocumentLoader _reportsLoader;
  final MapDocumentLoader _projectsLoader;

  static const _staffRoles = {
    'admin', 'super_admin', 'inspection_officer', 'receiving_clerk',
    'denr_officer', 'staff', 'menro_staff', 'denr_staff', 'menro', 'denr',
  };

  static bool canReadAllReports({
    required Map<String, dynamic> claims,
    required String profileRole,
  }) =>
      claims['admin'] == true ||
      _staffRoles.contains(claims['role']) ||
      _staffRoles.contains(profileRole);

  static Future<List<MapDocument>> _loadReports() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unauthenticated',
        message: 'Sign in to view map reports.',
      );
    }
    final token = await user.getIdTokenResult();
    final profile = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    Query<Map<String, dynamic>> query =
        FirebaseFirestore.instance.collection('reports');
    if (!canReadAllReports(
      claims: token.claims ?? {},
      profileRole: profile.data()?['role']?.toString() ?? '',
    )) {
      query = query.where('submittedBy', isEqualTo: user.uid);
    }
    final snapshot = await query.get();
    return snapshot.docs.map((doc) => MapDocument(doc.id, doc.data())).toList();
  }

  static Future<List<MapDocument>> _loadProjects() async {
    final snapshot = await FirebaseFirestore.instance.collection('projects').get();
    return snapshot.docs.map((doc) => MapDocument(doc.id, doc.data())).toList();
  }

  Future<MapRecordsResult> load() async {
    final layers = await Future.wait([
      _loadLayer(_reportsLoader, 'report', 'reports'),
      _loadLayer(_projectsLoader, 'project', 'projects'),
    ]);
    return MapRecordsResult(reports: layers[0], projects: layers[1]);
  }

  Future<MapLayerResult> _loadLayer(
    MapDocumentLoader loader,
    String type,
    String label,
  ) async {
    try {
      final documents = await loader();
      final records = <MapRecord>[];
      var unmappedCount = 0;
      for (final document in documents) {
        try {
          final record = MapRecord.fromDocument(document, type);
          if (record == null) {
            unmappedCount++;
          } else {
            records.add(record);
          }
        } on FormatException catch (error) {
          unmappedCount++;
          debugPrint('Map $type ${document.id}: $error');
        }
      }
      return MapLayerResult(records: records, unmappedCount: unmappedCount);
    } on FirebaseException catch (error) {
      debugPrint('Map $label load failed (${error.code}): ${error.message}');
      final message = switch (error.code) {
        'permission-denied' => 'You do not have access to these $label.',
        'unauthenticated' => 'Sign in to view $label.',
        _ => 'Could not load $label. Check your connection and retry.',
      };
      return MapLayerResult(error: message);
    }
  }
}
