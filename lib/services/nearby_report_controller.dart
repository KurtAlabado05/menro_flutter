import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/report_model.dart';

class NearbyReportController extends ChangeNotifier {
  NearbyReportController({
    required this.findNearby,
    this.debounce = const Duration(milliseconds: 300),
  });

  final Future<ReportModel?> Function(ReportModel) findNearby;
  final Duration debounce;
  Timer? _timer;
  int _generation = 0;
  bool _disposed = false;
  ReportModel? report;
  String? error;
  bool isChecking = false;

  void check(ReportModel? draft) {
    final generation = ++_generation;
    _timer?.cancel();
    report = null;
    error = null;
    isChecking = draft != null;
    notifyListeners();
    if (draft == null) return;
    _timer = Timer(debounce, () => unawaited(_lookup(draft, generation)));
  }

  Future<void> _lookup(ReportModel draft, int generation) async {
    try {
      final result = await findNearby(draft);
      if (_disposed || generation != _generation) return;
      report = result;
    } catch (e, stack) {
      debugPrint('Early nearby report check failed: $e\n$stack');
      if (_disposed || generation != _generation) return;
      error = 'Could not check nearby reports. Retry or continue; submission checks again.';
    } finally {
      if (!_disposed && generation == _generation) {
        isChecking = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _timer?.cancel();
    super.dispose();
  }
}
