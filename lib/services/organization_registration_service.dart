import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../firebase_service.dart';

class OrganizationFunctionException implements Exception {
  final String code;
  final String message;

  const OrganizationFunctionException(this.code, this.message);

  @override
  String toString() => message;
}

class OrganizationRegistrationService {
  const OrganizationRegistrationService();

  static const _workerBaseUrl = String.fromEnvironment(
    'ORG_REGISTRATION_WORKER_URL',
    defaultValue: 'https://cenro-functions-worker.kurtalabado0527.workers.dev',
  );
  static const _region = 'us-central1';
  Future<Map<String, dynamic>> submitApplication(Map<String, dynamic> data) {
    return _callWorker('/organization-admin/submit-application', data);
  }

  Future<Map<String, dynamic>> requestRepresentative(
    Map<String, dynamic> data,
  ) {
    return _callWorker('/organization-admin/submit-application', {
      ...data,
      'action': 'requestRepresentative',
    });
  }

  Future<Map<String, dynamic>> listPendingApplications() =>
      _call('listPendingOrganizationApplications', const {});

  Future<Map<String, dynamic>> reviewApplication({
    required String organizationId,
    required String decision,
    String? representativeUid,
  }) => _call('reviewOrganizationApplication', {
    'organizationId': organizationId,
    'decision': decision,
    if (representativeUid != null) 'representativeUid': representativeUid,
  });

  Future<Map<String, dynamic>> updateOrganizationPermit({
    required String organizationId,
    required String permitDocumentUrl,
  }) => _callWorker('/organization-admin/update-permit', {
    'organizationId': organizationId,
    'permitDocumentUrl': permitDocumentUrl,
  });

  Future<Map<String, dynamic>> rejectLookupRequest(String requestId) =>
      _call('rejectOrganizationLookupRequest', {'requestId': requestId});

  Future<Map<String, dynamic>> _callWorker(
    String path,
    Map<String, dynamic> data,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const OrganizationFunctionException(
        'unauthenticated',
        'Sign in before submitting an organization request.',
      );
    }

    final token = await user.getIdToken(true);
    if (token == null || token.isEmpty) {
      throw const OrganizationFunctionException(
        'unauthenticated',
        'Your sign-in session expired. Sign in again and retry.',
      );
    }

    final response = await http
        .post(
          Uri.parse('$_workerBaseUrl$path'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json; charset=utf-8',
          },
          body: jsonEncode(data),
        )
        .timeout(const Duration(seconds: 30));

    Map<String, dynamic> payload;
    try {
      payload = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    } catch (_) {
      throw const OrganizationFunctionException(
        'unavailable',
        'The organization service returned an invalid response. Please retry later.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = payload['error'];
      final errorData = error is Map ? error : const <String, dynamic>{};
      throw OrganizationFunctionException(
        (errorData['code'] ?? 'unavailable').toString(),
        (errorData['message'] ?? 'Unable to submit the organization request.')
            .toString(),
      );
    }
    return payload;
  }

  Future<Map<String, dynamic>> _call(
    String functionName,
    Map<String, dynamic> data,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const OrganizationFunctionException(
        'unauthenticated',
        'Sign in before submitting an organization request.',
      );
    }

    final token = await user.getIdToken(true);
    if (token == null || token.isEmpty) {
      throw const OrganizationFunctionException(
        'unauthenticated',
        'Your sign-in session expired. Sign in again and retry.',
      );
    }

    final endpoint = Uri.https(
      '$_region-${FirebaseConfig.projectId}.cloudfunctions.net',
      functionName,
    );
    final response = await http
        .post(
          endpoint,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json; charset=utf-8',
          },
          body: jsonEncode({'data': data}),
        )
        .timeout(const Duration(seconds: 30));

    Map<String, dynamic> payload;
    try {
      payload = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    } catch (_) {
      throw const OrganizationFunctionException(
        'unavailable',
        'The organization service returned an invalid response. Please retry later.',
      );
    }

    final error = payload['error'];
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        error is Map) {
      final errorData = error is Map ? error : const <String, dynamic>{};
      throw OrganizationFunctionException(
        (errorData['status'] ?? 'unavailable').toString().toLowerCase(),
        (errorData['message'] ?? 'Unable to submit the organization request.')
            .toString(),
      );
    }

    final result = payload['result'] ?? payload['data'];
    if (result is Map) return Map<String, dynamic>.from(result);
    throw const OrganizationFunctionException(
      'unavailable',
      'The organization service returned an invalid response. Please retry later.',
    );
  }
}
