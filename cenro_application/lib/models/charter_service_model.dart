import 'package:cloud_firestore/cloud_firestore.dart';

class CharterService {
  final String serviceCode;
  final String serviceCategory;
  final String serviceName;
  final int mandatedSlaHours;
  final double legalFees;
  final List<String> requiredDocumentsList;

  const CharterService({
    required this.serviceCode,
    required this.serviceCategory,
    required this.serviceName,
    required this.mandatedSlaHours,
    required this.legalFees,
    required this.requiredDocumentsList,
  });

  factory CharterService.fromFirestore(
    Map<String, dynamic> data, {
    required String documentId,
  }) {
    // Defensive parsing and type casting
    final serviceCode = (data['serviceCode'] as String?)?.trim().isNotEmpty == true
        ? (data['serviceCode'] as String).trim()
        : documentId;

    final serviceCategory = (data['serviceCategory'] as String?)?.trim() ?? '';
    final serviceName = (data['serviceName'] as String?)?.trim() ?? '';

    final mandatedSlaHoursRaw = data['mandatedSlaHours'];
    int mandatedSlaHours;
    if (mandatedSlaHoursRaw is int) {
      mandatedSlaHours = mandatedSlaHoursRaw;
    } else if (mandatedSlaHoursRaw is num) {
      mandatedSlaHours = mandatedSlaHoursRaw.toInt();
    } else {
      mandatedSlaHours = 0;
    }

    final legalFeesRaw = data['legalFees'];
    double legalFees;
    if (legalFeesRaw is double) {
      legalFees = legalFeesRaw;
    } else if (legalFeesRaw is num) {
      legalFees = legalFeesRaw.toDouble();
    } else {
      legalFees = 0.0;
    }

    final requiredDocumentsListRaw = data['requiredDocumentsList'];
    final requiredDocumentsList = <String>[];
    if (requiredDocumentsListRaw is List) {
      for (final item in requiredDocumentsListRaw) {
        if (item is String) {
          requiredDocumentsList.add(item);
        } else if (item != null) {
          requiredDocumentsList.add(item.toString());
        }
      }
    }

    return CharterService(
      serviceCode: serviceCode,
      serviceCategory: serviceCategory,
      serviceName: serviceName,
      mandatedSlaHours: mandatedSlaHours,
      legalFees: legalFees,
      requiredDocumentsList: requiredDocumentsList,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'serviceCode': serviceCode,
      'serviceCategory': serviceCategory,
      'serviceName': serviceName,
      'mandatedSlaHours': mandatedSlaHours,
      'legalFees': legalFees,
      'requiredDocumentsList': requiredDocumentsList,
    };
  }
}

