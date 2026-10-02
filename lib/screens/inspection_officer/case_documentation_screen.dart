import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../models/inspection_application_model.dart';
import '../../models/inspection_case_documentation_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/inspection_provider.dart';
import '../../services/cloudinary_image_service.dart';

class CaseDocumentationScreen extends StatefulWidget {
  final String? caseId;
  final Map<String, dynamic>? initialRecord;
  final InspectionApplicationModel? linkedSource;

  const CaseDocumentationScreen({
    super.key,
    this.caseId,
    this.initialRecord,
    this.linkedSource,
  });

  @override
  State<CaseDocumentationScreen> createState() =>
      _CaseDocumentationScreenState();
}

class _CaseDocumentationScreenState extends State<CaseDocumentationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _findingsController = TextEditingController();
  final _addressController = TextEditingController();
  final _barangayController = TextEditingController();
  final _attestationController = TextEditingController();
  final _treeCountController = TextEditingController();
  final _imagePicker = ImagePicker();
  final _photos = <_EvidencePhoto>[];
  final _files = <_EvidenceFile>[];

  static const _cloudinary = CloudinaryImageService(
    cloudName: 'dfo5l4d4t',
    uploadPreset: 'flutter_upload_preset',
  );

  String _caseType = 'environmental_report';
  String _urgency = 'normal';
  String _treeActionType = 'cutting';
  String _photoPhase = 'before';
  int _severity = 1;
  bool _attested = false;
  Map<String, bool> _checklistResponses = {};
  DateTime? _visitScheduledAt;
  DateTime? _attestedAt;
  String? _draftId;
  InspectionApplicationModel? _linkedApplication;
  double? _latitude;
  double? _longitude;
  double? _locationAccuracy;
  bool _capturingLocation = false;
  bool _saving = false;
  String? _error;

  static const _checklistTemplates = <String, List<String>>{
    'environmental_report': [
      'Site conditions documented',
      'Potential source or responsible activity identified',
      'Environmental impact observed and recorded',
      'Photo evidence captured with site context',
      'Immediate safety or containment action assessed',
    ],
    'tree_cutting_inspection': [
      'Species and number of trees verified',
      'Tree location corresponds to the application',
      'Distance to buildings, roads, or utilities checked',
      'Tree condition and hazard indicators documented',
      'Permit scope and requested action verified onsite',
    ],
  };

  @override
  void initState() {
    super.initState();
    final source = widget.linkedSource;
    if (source != null) {
      _linkedApplication = source;
      _caseType = source.sourceCollection == 'reports'
          ? 'environmental_report'
          : 'tree_cutting_inspection';
      _titleController.text =
          (source.raw['title'] ??
                  (source.sourceCollection == 'reports'
                      ? source.category
                      : '${source.applicantName} tree inspection'))
              .toString();
      _findingsController.text = source.sourceCollection == 'reports'
          ? source.description
          : (source.raw['reasonForRequest'] ?? '').toString();
      _addressController.text = source.applicationAddress;
      _barangayController.text = (source.raw['barangay'] ?? '').toString();
      _treeCountController.text = (source.raw['numberOfTrees'] ?? '')
          .toString();
      _latitude = (source.raw['latitude'] as num?)?.toDouble();
      _longitude = (source.raw['longitude'] as num?)?.toDouble();
    }
    final record = widget.initialRecord;
    if (record == null) return;
    _draftId = widget.caseId;
    _titleController.text = (record['title'] ?? '').toString();
    _findingsController.text = (record['findings'] ?? '').toString();
    _addressController.text = (record['siteAddress'] ?? '').toString();
    _barangayController.text = (record['barangay'] ?? '').toString();
    _attestationController.text = (record['officerAttestation'] ?? '')
        .toString();
    _treeCountController.text = (record['treeCount'] ?? '').toString();
    _caseType = (record['caseType'] ?? _caseType).toString();
    _urgency = (record['urgency'] ?? _urgency).toString();
    _treeActionType = (record['treeActionType'] ?? _treeActionType).toString();
    _severity = record['severity'] is int
        ? record['severity'] as int
        : _severity;
    _attested = record['officerAttested'] == true;
    _attestedAt = _parseDate(record['attestedAt']);
    _latitude = (record['latitude'] as num?)?.toDouble();
    _longitude = (record['longitude'] as num?)?.toDouble();
    _locationAccuracy = (record['locationAccuracy'] as num?)?.toDouble();
    _visitScheduledAt = _parseDate(record['visitScheduledAt']);
    final checklist = record['checklistResponses'];
    if (checklist is Map) {
      _checklistResponses = checklist.map(
        (key, value) => MapEntry(key.toString(), value == true),
      );
    }
    final photos = record['photos'];
    if (photos is List) {
      _photos.addAll(
        photos.whereType<Map>().map((item) {
          final photo = Map<String, dynamic>.from(item);
          return _EvidencePhoto.fromMap(photo);
        }),
      );
    }
    final files = record['files'];
    if (files is List) {
      _files.addAll(
        files.whereType<Map>().map((item) {
          final file = Map<String, dynamic>.from(item);
          return _EvidenceFile(
            name: (file['name'] ?? 'File').toString(),
            bytes: null,
            uploadedUrl: (file['url'] ?? '').toString().isEmpty
                ? null
                : file['url'].toString(),
          );
        }),
      );
    }
  }

  static DateTime? _parseDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value?.toString() ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _findingsController.dispose();
    _addressController.dispose();
    _barangayController.dispose();
    _attestationController.dispose();
    _treeCountController.dispose();
    super.dispose();
  }

  Future<void> _captureLocation() async {
    setState(() {
      _capturingLocation = true;
      _error = null;
    });
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission is required to capture the site.');
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Enable location services and try again.');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      var address = '';
      var barangay = '';
      try {
        final places = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (places.isNotEmpty) {
          final place = places.first;
          barangay = place.subLocality ?? place.locality ?? '';
          address = [
            place.street,
            place.subLocality,
            place.locality,
            place.administrativeArea,
          ].where((part) => part != null && part.trim().isNotEmpty).join(', ');
        }
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _locationAccuracy = position.accuracy;
        if (address.isNotEmpty) _addressController.text = address;
        if (barangay.isNotEmpty) _barangayController.text = barangay;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _capturingLocation = false);
    }
  }

  Future<void> _addPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a Photo'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1600,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(
        () => _photos.add(
          _EvidencePhoto(name: picked.name, bytes: bytes, phase: _photoPhase),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load photo: $e');
    }
  }

  Future<void> _addFiles() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
        allowMultiple: true,
        withData: true,
      );
      if (result == null || !mounted) return;
      final files = result.files
          .where((file) => file.bytes != null)
          .map((file) => _EvidenceFile(name: file.name, bytes: file.bytes!));
      setState(() => _files.addAll(files));
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load files: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _uploadPhotos(String caseId) async {
    final uploaded = <Map<String, dynamic>>[];
    for (var index = 0; index < _photos.length; index++) {
      final photo = _photos[index];
      var url = photo.uploadedUrl;
      if (url == null && photo.bytes != null) {
        url = await _cloudinary.uploadImage(
          bytes: photo.bytes!,
          fileName: 'inspection_${caseId}_photo_${index}_${photo.name}',
        );
        _photos[index] = photo.copyWith(uploadedUrl: url);
      }
      if (url == null) continue;
      uploaded.add(photo.toMap(url));
    }
    return uploaded;
  }

  Future<List<Map<String, String>>> _uploadFiles(String caseId) async {
    final uploaded = <Map<String, String>>[];
    for (var index = 0; index < _files.length; index++) {
      final file = _files[index];
      var url = file.uploadedUrl;
      if (url == null && file.bytes != null) {
        url = await _cloudinary.uploadRawFile(
          bytes: file.bytes!,
          fileName: 'inspection_${caseId}_file_${index}_${file.name}',
        );
        _files[index] = file.copyWith(uploadedUrl: url);
      }
      if (url == null) continue;
      uploaded.add({'name': file.name, 'url': url});
    }
    return uploaded;
  }

  Future<void> _editPhotoAnnotation(int index) async {
    final photo = _photos[index];
    final captionController = TextEditingController(text: photo.caption);
    final measurementController = TextEditingController(
      text: photo.measurementCm?.toString() ?? '',
    );
    var marker = photo.annotationPoint;
    final result = await showDialog<(String, String, Offset?)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Annotate Evidence'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 240,
                  height: 240,
                  child: LayoutBuilder(
                    builder: (context, constraints) => GestureDetector(
                      onTapDown: (details) => setDialogState(() {
                        marker = Offset(
                          (details.localPosition.dx / constraints.maxWidth)
                              .clamp(0, 1),
                          (details.localPosition.dy / constraints.maxHeight)
                              .clamp(0, 1),
                        );
                      }),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (photo.bytes != null)
                            Image.memory(photo.bytes!, fit: BoxFit.cover)
                          else if (photo.uploadedUrl != null)
                            Image.network(photo.uploadedUrl!, fit: BoxFit.cover)
                          else
                            const ColoredBox(color: Colors.black12),
                          if (marker != null)
                            Positioned(
                              left: marker!.dx * constraints.maxWidth - 12,
                              top: marker!.dy * constraints.maxHeight - 24,
                              child: const Icon(
                                Icons.location_on,
                                color: Colors.red,
                                size: 26,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: captionController,
                  decoration: const InputDecoration(
                    labelText: 'Annotation / tree tag',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: measurementController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Trunk diameter (cm)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, (
                captionController.text.trim(),
                measurementController.text.trim(),
                marker,
              )),
              child: const Text('Save Annotation'),
            ),
          ],
        ),
      ),
    );
    captionController.dispose();
    measurementController.dispose();
    if (result == null || !mounted) return;
    setState(() {
      _photos[index] = photo.copyWith(
        caption: result.$1,
        measurementCm: double.tryParse(result.$2),
        annotationPoint: result.$3,
      );
    });
  }

  Future<void> _pickVisitDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _visitScheduledAt ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: _visitScheduledAt == null
          ? TimeOfDay.now()
          : TimeOfDay.fromDateTime(_visitScheduledAt!),
    );
    if (time == null || !mounted) return;
    setState(() {
      _visitScheduledAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _save({required String status}) async {
    if (status == 'submitted') {
      if (!_formKey.currentState!.validate()) return;
      if (!_attested || _attestationController.text.trim().isEmpty) {
        setState(
          () => _error = 'Add your typed attestation before submitting.',
        );
        return;
      }
    } else if (_titleController.text.trim().isEmpty) {
      setState(() => _error = 'Enter a case title before saving a draft.');
      return;
    }
    final user = context.read<AuthProvider>().user;
    final inspectionProvider = context.read<InspectionProvider>();
    if (user == null) {
      setState(
        () => _error = 'Your session has expired. Please sign in again.',
      );
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final caseId = _draftId ??=
        widget.caseId ??
        'case_${user.id}_${DateTime.now().millisecondsSinceEpoch}';
    var draftPersisted = false;
    try {
      final linked = _linkedApplication;
      final title = _titleController.text.trim();
      final previousHistory =
          (widget.initialRecord?['activityHistory'] as List? ?? const [])
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
      final history = [...previousHistory];
      if (history.isEmpty) {
        history.add({
          'event': 'draft_created',
          'actorId': user.id,
          'actorName': user.contextualName,
          'at': DateTime.now().toIso8601String(),
        });
      }
      InspectionCaseDocumentationModel buildRecord({
        required String recordStatus,
        required List<Map<String, dynamic>> photos,
        required List<Map<String, String>> files,
      }) {
        return InspectionCaseDocumentationModel(
          id: caseId,
          caseType: _caseType,
          title: title,
          findings: _findingsController.text.trim(),
          severity: _severity,
          urgency: _urgency,
          siteAddress: _addressController.text.trim(),
          barangay: _barangayController.text.trim(),
          latitude: _latitude,
          longitude: _longitude,
          locationAccuracy: _locationAccuracy,
          photos: photos,
          files: files,
          checklistResponses: {
            for (final item
                in _checklistTemplates[_caseType] ?? const <String>[])
              item: _checklistResponses[item] == true,
          },
          officerAttested: _attested,
          officerAttestation: _attested
              ? _attestationController.text.trim()
              : '',
          attestedAt: _attested ? (_attestedAt ?? DateTime.now()) : null,
          visitScheduledAt: _visitScheduledAt,
          treeCount: int.tryParse(_treeCountController.text.trim()) ?? 0,
          treeActionType: _treeActionType,
          seedlingsRequired: _treeActionType == 'cutting'
              ? (int.tryParse(_treeCountController.text.trim()) ?? 0) * 3
              : 0,
          seedlingsPlanted:
              (widget.initialRecord?['seedlingsPlanted'] as num?)?.toInt() ?? 0,
          activityHistory: history,
          linkedApplicationId:
              linked?.id ??
              widget.initialRecord?['linkedApplicationId']?.toString(),
          linkedApplicationCollection:
              linked?.sourceCollection ??
              widget.initialRecord?['linkedApplicationCollection']?.toString(),
          inspectorId: user.id,
          inspectorName: user.contextualName,
          status: recordStatus,
          recordedAt: DateTime.now(),
        );
      }

      final existingPhotos = _photos
          .where((photo) => photo.uploadedUrl != null)
          .map((photo) => photo.toMap(photo.uploadedUrl!))
          .toList();
      final existingFiles = _files
          .where((file) => file.uploadedUrl != null)
          .map((file) => {'name': file.name, 'url': file.uploadedUrl!})
          .toList();

      await inspectionProvider.saveCaseDocumentation(
        buildRecord(
          recordStatus: 'draft',
          photos: existingPhotos,
          files: existingFiles,
        ),
      );
      draftPersisted = true;

      final photos = await _uploadPhotos(caseId);
      final files = await _uploadFiles(caseId);
      if (status != 'draft') {
        history.add({
          'event': 'case_submitted',
          'actorId': user.id,
          'actorName': user.contextualName,
          'at': DateTime.now().toIso8601String(),
        });
      }
      await inspectionProvider.updateCaseDocumentation(
        buildRecord(recordStatus: status, photos: photos, files: files),
      );
      _draftId = caseId;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'draft' ? 'Draft saved' : 'Case documentation submitted',
          ),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = draftPersisted
              ? 'Draft saved. Evidence is still waiting to upload: $e'
              : e.toString(),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final queue = context.watch<InspectionProvider>().queue;
    final linkableSubmissions = queue
        .where(
          (item) =>
              item.sourceCollection == 'reports' ||
              item.type == 'tree_cutting_permit',
        )
        .toList();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Case Documentation'),
        backgroundColor: AppColors.primary,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              initialValue: _caseType,
              decoration: const InputDecoration(
                labelText: 'Case Type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'environmental_report',
                  child: Text('Onsite Environmental Report'),
                ),
                DropdownMenuItem(
                  value: 'tree_cutting_inspection',
                  child: Text('Tree Cutting Location Inspection'),
                ),
              ],
              onChanged: _saving
                  ? null
                  : (value) => setState(() {
                      _caseType = value ?? _caseType;
                      for (final item
                          in _checklistTemplates[_caseType] ??
                              const <String>[]) {
                        _checklistResponses.putIfAbsent(item, () => false);
                      }
                    }),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Case Title',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a case title.'
                  : null,
            ),
            const SizedBox(height: 12),
            if (linkableSubmissions.isNotEmpty) ...[
              DropdownButtonFormField<String>(
                initialValue: _linkedApplication == null
                    ? null
                    : '${_linkedApplication!.sourceCollection}:${_linkedApplication!.id}',
                decoration: const InputDecoration(
                  labelText: 'Related Submission (optional)',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('No linked submission'),
                  ),
                  ...linkableSubmissions.map(
                    (application) => DropdownMenuItem(
                      value:
                          '${application.sourceCollection}:${application.id}',
                      child: Text(
                        application.sourceCollection == 'reports'
                            ? '${application.category} · ${application.applicantName}'
                            : '${application.applicantName} · ${application.type}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: _saving
                    ? null
                    : (key) => setState(() {
                        _linkedApplication = key == null
                            ? null
                            : linkableSubmissions.firstWhere(
                                (item) =>
                                    '${item.sourceCollection}:${item.id}' ==
                                    key,
                              );
                      }),
              ),
              const SizedBox(height: 12),
            ],
            _LocationCard(
              addressController: _addressController,
              barangayController: _barangayController,
              latitude: _latitude,
              longitude: _longitude,
              accuracy: _locationAccuracy,
              loading: _capturingLocation,
              onCapture: _captureLocation,
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.event_outlined,
                color: AppColors.primary,
              ),
              title: const Text('Schedule a follow-up visit'),
              subtitle: Text(
                _visitScheduledAt == null
                    ? 'No visit scheduled'
                    : '${_visitScheduledAt!.year}-${_visitScheduledAt!.month.toString().padLeft(2, '0')}-${_visitScheduledAt!.day.toString().padLeft(2, '0')} at ${TimeOfDay.fromDateTime(_visitScheduledAt!).format(context)}',
              ),
              trailing: IconButton(
                tooltip: 'Choose visit date and time',
                onPressed: _saving ? null : _pickVisitDate,
                icon: const Icon(Icons.edit_calendar_outlined),
              ),
            ),
            if (_caseType == 'tree_cutting_inspection') ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _treeCountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Trees inspected',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _treeActionType,
                      decoration: const InputDecoration(
                        labelText: 'Action',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'cutting',
                          child: Text('Cutting'),
                        ),
                        DropdownMenuItem(
                          value: 'trimming',
                          child: Text('Trimming'),
                        ),
                      ],
                      onChanged: _saving
                          ? null
                          : (value) => setState(
                              () => _treeActionType = value ?? 'cutting',
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Seedlings expected: ${_treeActionType == 'cutting' ? (int.tryParse(_treeCountController.text) ?? 0) * 3 : 0}',
                style: const TextStyle(color: AppColors.textGrey, fontSize: 12),
              ),
            ],
            DropdownButtonFormField<int>(
              initialValue: _severity,
              decoration: const InputDecoration(
                labelText: 'Severity',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 1, child: Text('1 · Low')),
                DropdownMenuItem(value: 2, child: Text('2 · Minor')),
                DropdownMenuItem(value: 3, child: Text('3 · Moderate')),
                DropdownMenuItem(value: 4, child: Text('4 · High')),
                DropdownMenuItem(value: 5, child: Text('5 · Critical')),
              ],
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _severity = value ?? 1),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _urgency,
              decoration: const InputDecoration(
                labelText: 'Urgency',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'normal', child: Text('Normal')),
                DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
                DropdownMenuItem(value: 'critical', child: Text('Critical')),
              ],
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _urgency = value ?? 'normal'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _findingsController,
              minLines: 4,
              maxLines: 8,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Findings and Recommendations',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Record the inspection findings.'
                  : null,
            ),
            const SizedBox(height: 16),
            _ChecklistCard(
              title: _caseType == 'tree_cutting_inspection'
                  ? 'Tree Site Checklist'
                  : 'Environmental Site Checklist',
              items: _checklistTemplates[_caseType] ?? const [],
              responses: _checklistResponses,
              onChanged: (item, checked) =>
                  setState(() => _checklistResponses[item] = checked),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.cardWhite,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _attested,
                    onChanged: _saving
                        ? null
                        : (value) => setState(() {
                            _attested = value ?? false;
                            if (_attested) _attestedAt ??= DateTime.now();
                          }),
                    title: const Text('Officer attestation'),
                    subtitle: const Text(
                      'I certify that these findings reflect my site inspection.',
                    ),
                  ),
                  TextField(
                    controller: _attestationController,
                    enabled: _attested && !_saving,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Type your full name to attest',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _EvidenceSection(
              photos: _photos,
              files: _files,
              selectedPhase: _photoPhase,
              onAddPhoto: _addPhoto,
              onAddFiles: _addFiles,
              onPhaseChanged: (phase) => setState(() => _photoPhase = phase),
              onAnnotatePhoto: _editPhotoAnnotation,
              onRemovePhoto: (index) => setState(() => _photos.removeAt(index)),
              onRemoveFile: (index) => setState(() => _files.removeAt(index)),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Colors.red.shade700)),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : () => _save(status: 'draft'),
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save Draft'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _saving
                        ? null
                        : () => _save(status: 'submitted'),
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_outlined),
                    label: const Text('Submit Case'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _ChecklistCard extends StatelessWidget {
  final String title;
  final List<String> items;
  final Map<String, bool> responses;
  final void Function(String item, bool checked) onChanged;

  const _ChecklistCard({
    required this.title,
    required this.items,
    required this.responses,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          ...items.map(
            (item) => CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: responses[item] ?? false,
              title: Text(item, style: const TextStyle(fontSize: 13)),
              onChanged: (checked) => onChanged(item, checked ?? false),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  final TextEditingController addressController;
  final TextEditingController barangayController;
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final bool loading;
  final VoidCallback onCapture;

  const _LocationCard({
    required this.addressController,
    required this.barangayController,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.loading,
    required this.onCapture,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Inspection Site',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: 'Capture GPS location',
                onPressed: loading ? null : onCapture,
                icon: loading
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location),
              ),
            ],
          ),
          TextFormField(
            controller: addressController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Site Address'),
          ),
          TextFormField(
            controller: barangayController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Barangay'),
          ),
          const SizedBox(height: 8),
          Text(
            latitude == null || longitude == null
                ? 'GPS location not captured'
                : 'GPS: ${latitude!.toStringAsFixed(6)}, ${longitude!.toStringAsFixed(6)}'
                      '${accuracy == null ? '' : ' · ±${accuracy!.round()} m'}',
            style: const TextStyle(color: AppColors.textGrey, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _EvidencePhoto {
  final String name;
  final Uint8List? bytes;
  final String? uploadedUrl;
  final String phase;
  final String caption;
  final double? measurementCm;
  final Offset? annotationPoint;

  const _EvidencePhoto({
    required this.name,
    this.bytes,
    this.uploadedUrl,
    this.phase = 'before',
    this.caption = '',
    this.measurementCm,
    this.annotationPoint,
  });

  factory _EvidencePhoto.fromMap(Map<String, dynamic> map) {
    final point = map['annotationPoint'];
    final url = (map['url'] ?? '').toString();
    return _EvidencePhoto(
      name: (map['name'] ?? 'Photo').toString(),
      uploadedUrl: url.isEmpty ? null : url,
      phase: (map['phase'] ?? 'before').toString(),
      caption: (map['caption'] ?? '').toString(),
      measurementCm: (map['measurementCm'] as num?)?.toDouble(),
      annotationPoint: point is Map
          ? Offset(
              (point['x'] as num?)?.toDouble() ?? 0,
              (point['y'] as num?)?.toDouble() ?? 0,
            )
          : null,
    );
  }

  _EvidencePhoto copyWith({
    String? uploadedUrl,
    String? caption,
    double? measurementCm,
    Offset? annotationPoint,
  }) => _EvidencePhoto(
    name: name,
    bytes: bytes,
    uploadedUrl: uploadedUrl ?? this.uploadedUrl,
    phase: phase,
    caption: caption ?? this.caption,
    measurementCm: measurementCm ?? this.measurementCm,
    annotationPoint: annotationPoint ?? this.annotationPoint,
  );

  Map<String, dynamic> toMap(String url) => {
    'name': name,
    'url': url,
    'phase': phase,
    'caption': caption,
    'measurementCm': measurementCm,
    if (annotationPoint != null)
      'annotationPoint': {'x': annotationPoint!.dx, 'y': annotationPoint!.dy},
  };
}

class _EvidenceFile {
  final String name;
  final Uint8List? bytes;
  final String? uploadedUrl;

  const _EvidenceFile({required this.name, this.bytes, this.uploadedUrl});

  _EvidenceFile copyWith({String? uploadedUrl}) => _EvidenceFile(
    name: name,
    bytes: bytes,
    uploadedUrl: uploadedUrl ?? this.uploadedUrl,
  );
}

class _EvidenceSection extends StatelessWidget {
  final List<_EvidencePhoto> photos;
  final List<_EvidenceFile> files;
  final String selectedPhase;
  final VoidCallback onAddPhoto;
  final VoidCallback onAddFiles;
  final ValueChanged<String> onPhaseChanged;
  final ValueChanged<int> onRemovePhoto;
  final ValueChanged<int> onRemoveFile;
  final ValueChanged<int> onAnnotatePhoto;

  const _EvidenceSection({
    required this.photos,
    required this.files,
    required this.selectedPhase,
    required this.onAddPhoto,
    required this.onAddFiles,
    required this.onPhaseChanged,
    required this.onRemovePhoto,
    required this.onRemoveFile,
    required this.onAnnotatePhoto,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Evidence', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'before', label: Text('Before')),
              ButtonSegment(value: 'after', label: Text('After')),
            ],
            selected: {selectedPhase},
            onSelectionChanged: (selection) => onPhaseChanged(selection.first),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onAddPhoto,
                icon: const Icon(Icons.add_a_photo_outlined),
                label: const Text('Add Photo'),
              ),
              OutlinedButton.icon(
                onPressed: onAddFiles,
                icon: const Icon(Icons.attach_file),
                label: const Text('Attach Files'),
              ),
            ],
          ),
          if (photos.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) => Stack(
                  children: [
                    InkWell(
                      onTap: () => onAnnotatePhoto(index),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 96,
                          height: 96,
                          child: photos[index].bytes != null
                              ? Image.memory(
                                  photos[index].bytes!,
                                  fit: BoxFit.cover,
                                )
                              : Image.network(
                                  photos[index].uploadedUrl!,
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 4,
                      bottom: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        color: Colors.black54,
                        child: Text(
                          photos[index].phase,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: IconButton.filledTonal(
                        onPressed: () => onRemovePhoto(index),
                        icon: const Icon(Icons.close, size: 16),
                        tooltip: 'Remove photo',
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          ...files.asMap().entries.map(
            (entry) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(Icons.insert_drive_file_outlined),
              title: Text(
                entry.value.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                tooltip: 'Remove file',
                onPressed: () => onRemoveFile(entry.key),
                icon: const Icon(Icons.close),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
