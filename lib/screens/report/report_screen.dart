import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_tokens.dart';
import '../../widgets/custom_button.dart';
import 'report_location_picker.dart';
import '../../models/report_location.dart';
import '../../models/report_model.dart';
import '../../providers/auth_provider.dart' as app_auth_provider;
import '../../providers/report_provider.dart';
import '../../services/geo/report_location_resolver.dart';
import '../../services/geo/reverse_geocoding_service.dart';
import '../../services/location/device_location_service.dart';
import '../../services/media/photo_metadata_service.dart';
import '../../services/media/report_photo_upload_queue.dart';
import '../../services/media/report_camera_service.dart';
import '../../services/nearby_report_controller.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/custom_textfield.dart';
import '../../widgets/image_source_sheet.dart';
import '../../widgets/section_widgets.dart';
import '../submissions/my_submissions_screen.dart';
import 'picked_image.dart';
import 'report_camera_screen.dart';
import 'widgets/report_location_card.dart';
import 'widgets/report_photo_strip.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({
    super.key,
    this.deviceLocation,
    this.locationResolver,
    this.imagePicker,
    this.photoMetadata,
    this.photoUploader,
    this.cameraService = const ReportCameraService(),
  });

  final DeviceLocationService? deviceLocation;
  final ReportLocationResolver? locationResolver;
  final ImagePicker? imagePicker;
  final PhotoMetadataService? photoMetadata;
  final ReportPhotoUploader? photoUploader;
  final ReportCameraService cameraService;

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  final _fullAddressController = TextEditingController();
  final _barangayController = TextEditingController();
  final _streetController = TextEditingController();
  final _landmarkController = TextEditingController();

  final _reporterNameController = TextEditingController();
  final _contactController = TextEditingController();

  String _selectedCategory = _categories.first;
  static const List<String> _categories = [
    'Illegal Dumping of Solid Waste',
    'Waterway Pollution',
    'Improper Liquid/Wastewater Disposal',
    'Open Burning of Waste',
    'Public smoking violation',
    'Littering / Public vandalism',
  ];

  static const Map<String, IconData> _categoryIcons = {
    'Illegal Dumping of Solid Waste': Icons.warning_amber_outlined,
    'Waterway Pollution': Icons.water_outlined,
    'Improper Liquid/Wastewater Disposal': Icons.water_drop_outlined,
    'Open Burning of Waste': Icons.local_fire_department_outlined,
    'Public smoking violation': Icons.smoke_free,
    'Littering / Public vandalism': Icons.report_outlined,
  };

  final List<PickedImage> _selectedImages = [];
  late final ReportPhotoUploadQueue _uploads =
      ReportPhotoUploadQueue(uploader: widget.photoUploader);
  late final NearbyReportController _nearby;
  bool _isAddingSupport = false;

  final ReverseGeocodingService _geocoder = ReverseGeocodingService();
  late final DeviceLocationService _deviceLocation =
      widget.deviceLocation ?? const DeviceLocationService();
  late final PhotoMetadataService _photoMetadata =
      widget.photoMetadata ?? const PhotoMetadataService();
  late final ImagePicker _imagePicker = widget.imagePicker ?? ImagePicker();
  late final ReportLocationResolver _locationResolver =
      widget.locationResolver ?? ReportLocationResolver(geocoder: _geocoder);

  bool _isUploadingImages = false;
  bool _isPickingPhoto = false;
  bool _isFetchingLocation = false;
  double? _latitude;
  double? _longitude;
  ReportLocationSource _locationSource = ReportLocationSource.unknown;
  double? _locationAccuracyMeters;
  bool _locationOutsideBoundary = false;

  /// Bumped every time a new location is requested or set so a slow,
  /// in-flight GPS fetch can detect it has been superseded (e.g. by a
  /// manual map pick) and discard its result instead of overwriting it.
  int _locationRequestId = 0;

  bool get _hasInput =>
      _titleController.text.trim().isNotEmpty ||
      _descController.text.trim().isNotEmpty ||
      _selectedImages.isNotEmpty;

  int _severityForCategory(String category) {
    switch (category.trim()) {
      case 'Littering / Public vandalism':
        return 1;
      case 'Public smoking violation':
        return 2;
      case 'Waterway Pollution':
        return 3;
      case 'Improper Liquid/Wastewater Disposal':
      case 'Open Burning of Waste':
        return 4;
      case 'Illegal Dumping of Solid Waste':
        return 5;
      default:
        return 1;
    }
  }

  @override
  void initState() {
    super.initState();
    _uploads.addListener(_draftChanged);
    final provider = context.read<ReportProvider>();
    _nearby = NearbyReportController(findNearby: provider.findNearbyActiveReport)
      ..addListener(_draftChanged);
    _prefillFromAccount();
    _autoFetchLocation();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      _recoverLostPhoto();
    }
  }

  void _prefillFromAccount() {
    final user = context.read<app_auth_provider.AuthProvider>().user;
    if (user == null) return;

    _reporterNameController.text = user.contextualName;
    final phone = user.phoneNumber;
    if (phone != null && phone.trim().isNotEmpty) {
      _contactController.text = phone.trim();
    }
  }

  @override
  void dispose() {
    _nearby.removeListener(_draftChanged);
    _nearby.dispose();
    _uploads.removeListener(_draftChanged);
    _uploads.dispose();
    _titleController.dispose();
    _descController.dispose();
    _fullAddressController.dispose();
    _barangayController.dispose();
    _streetController.dispose();
    _landmarkController.dispose();
    _reporterNameController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  void _draftChanged() {
    if (mounted) setState(() {});
  }

  void _checkNearby() {
    _nearby.check(_latitude == null || _longitude == null
        ? null
        : _buildReport(
            id: 'draft', userId: '', userName: '',
            submittedAt: DateTime.now(),
          ));
  }

  /// Fetches the incident location: shows a cached GPS fix immediately if
  /// one is available (so the card fills in almost instantly), then
  /// refines it with a fresh high-accuracy fix in the background.
  Future<void> _autoFetchLocation() async {
    final requestId = ++_locationRequestId;
    if (mounted) setState(() => _isFetchingLocation = true);
    var hasAppliedCachedFix = false;
    try {
      final availability = await _deviceLocation.checkAvailability();
      if (!mounted || requestId != _locationRequestId) return;
      if (availability != LocationAvailability.available) {
        if (availability.message != null) {
          showAppSnackBar(context, availability.message!, type: AppMessageType.warning);
        }
        return;
      }

      final cached = await _deviceLocation.lastKnown();
      if (!mounted || requestId != _locationRequestId) return;
      final freshFix = _deviceLocation.currentFix();
      // Attach a handler immediately while the cached address is resolving.
      final freshResult = freshFix.then<LocationFix?>(
        (fix) => fix,
        onError: (Object error, StackTrace stack) {
          debugPrint('Fresh report GPS fix failed: $error');
          return null;
        },
      );
      if (cached != null) {
        await _applyFix(
          latitude: cached.latitude,
          longitude: cached.longitude,
          accuracyMeters: cached.accuracyMeters,
          source: ReportLocationSource.deviceGps,
          requestId: requestId,
        );
        hasAppliedCachedFix = _latitude != null && _longitude != null;
      }

      final fresh = await freshResult;
      if (!mounted || requestId != _locationRequestId) return;
      if (fresh == null) {
        showAppSnackBar(
          context,
          hasAppliedCachedFix
              ? 'Could not refresh GPS. Review the cached location or pick on map.'
              : 'Could not get GPS. Pick the spot on the map.',
          type: AppMessageType.warning,
        );
        return;
      }
      await _applyFix(
        latitude: fresh.latitude,
        longitude: fresh.longitude,
        accuracyMeters: fresh.accuracyMeters,
        source: ReportLocationSource.deviceGps,
        requestId: requestId,
      );
    } catch (e) {
      debugPrint('Location error: $e');
      // Don't pile on a generic failure message if we already showed the
      // user something useful from the cached warm-up fix.
      if (mounted && requestId == _locationRequestId && !hasAppliedCachedFix) {
        showAppSnackBar(
          context,
          'Could not get your location. Pick the spot on the map instead.',
          type: AppMessageType.warning,
        );
      }
    } finally {
      if (mounted && requestId == _locationRequestId) {
        setState(() => _isFetchingLocation = false);
      }
    }
  }

  /// Resolves raw coordinates and applies them to the form, but only if
  /// [requestId] is still the most recent request (i.e. nothing newer — a
  /// manual map pick or another refresh — has superseded it in the
  /// meantime).
  Future<void> _applyFix({
    required double latitude,
    required double longitude,
    required double? accuracyMeters,
    required ReportLocationSource source,
    required int requestId,
  }) async {
    if (!mounted || requestId != _locationRequestId) return;
    if (source != ReportLocationSource.photoExif &&
        accuracyLevelFor(accuracyMeters) == LocationAccuracyLevel.poor) {
      setState(() {
        _latitude = null;
        _longitude = null;
        _locationAccuracyMeters = accuracyMeters;
        _locationSource = source;
        _locationOutsideBoundary = false;
        _clearLocationAddress();
      });
      _checkNearby();
      showAppSnackBar(
        context,
        'GPS accuracy is too low. Confirm the incident location on the map.',
        type: AppMessageType.warning,
      );
      return;
    }
    final resolved = await _locationResolver.resolve(
      latitude: latitude,
      longitude: longitude,
      source: source,
      accuracyMeters: accuracyMeters,
    );
    if (!mounted || requestId != _locationRequestId) return;

    if (resolved == null) {
      final wasAlreadyFlagged = _locationOutsideBoundary;
      setState(() {
        _locationOutsideBoundary = true;
        _latitude = null;
        _longitude = null;
        _clearLocationAddress();
      });
      _checkNearby();
      if (!wasAlreadyFlagged) {
        showAppSnackBar(
          context,
          'You appear to be outside Baliwag. Pick the exact spot on the map.',
          type: AppMessageType.warning,
        );
      }
      return;
    }

    setState(() {
      _locationOutsideBoundary = false;
      _latitude = resolved.latitude;
      _longitude = resolved.longitude;
      _locationAccuracyMeters = resolved.accuracyMeters;
      _locationSource = resolved.source;
      _barangayController.text = resolved.barangay ?? '';
      _streetController.text = resolved.street ?? '';
      _landmarkController.text = resolved.landmark ?? '';
      _fullAddressController.text = resolved.displayAddress;
    });
    _checkNearby();
  }

  void _clearLocationAddress() {
    _barangayController.clear();
    _streetController.clear();
    _landmarkController.clear();
    _fullAddressController.clear();
  }

  Future<void> _pickOnMap() async {
    final result = await Navigator.push<ReportLocation>(
      context,
      MaterialPageRoute(
        builder: (_) => ReportLocationPickerScreen(
          initialLat: _latitude,
          initialLng: _longitude,
        ),
      ),
    );
    if (result == null || !mounted) return;

    // A manual pick always wins: bump the request token so any in-flight
    // GPS fetch becomes stale and can no longer overwrite this choice when
    // it completes.
    _locationRequestId++;
    setState(() {
      _isFetchingLocation = false;
      _locationOutsideBoundary = false;
      _latitude = result.latitude;
      _longitude = result.longitude;
      _locationAccuracyMeters = result.accuracyMeters;
      _locationSource = ReportLocationSource.manual;
      _fullAddressController.text = result.address ?? '';
      _barangayController.text = result.barangay ?? '';
      _streetController.text = result.street ?? '';
      _landmarkController.text = result.landmark ?? '';
    });
    _checkNearby();
  }

  Future<void> _pickImage([ImageSource? requestedSource]) async {
    if (_isPickingPhoto || _isUploadingImages) return;
    setState(() => _isPickingPhoto = true);
    try {
      final source = requestedSource ?? await showImageSourceSheet(context);
      if (source == null || !mounted) return;
      final requestId = _locationRequestId;
      final ownsLocation = _selectedImages.isEmpty &&
          _locationSource != ReportLocationSource.manual;
      final cameraFix = source == ImageSource.camera && ownsLocation
          ? _cameraLocationFix()
          : null;
      final picked = source == ImageSource.camera
          ? await Navigator.push<XFile>(
              context,
              MaterialPageRoute(
                builder: (_) => ReportCameraScreen(
                  cameraService: widget.cameraService,
                ),
              ),
            )
          : await _imagePicker.pickImage(
              source: ImageSource.gallery,
              requestFullMetadata: true,
            );
      if (picked == null || !mounted) return;
      final capturedAt = DateTime.now();
      final prepared = await _photoMetadata.prepare(await picked.readAsBytes());
      if (!mounted) return;
      _attachPhoto(picked, prepared);
      if (prepared.metadataWarning != null) {
        showAppSnackBar(context, prepared.metadataWarning!,
            type: AppMessageType.warning);
      }
      if (!ownsLocation || requestId != _locationRequestId ||
          _locationSource == ReportLocationSource.manual) {
        return;
      }

      if (source == ImageSource.gallery && prepared.metadata.hasLocation) {
        final metadata = prepared.metadata;
        final takenAt = metadata.takenAt;
        final oldPhoto = takenAt != null &&
            capturedAt.difference(takenAt) > const Duration(hours: 48);
        final takenElsewhere = _latitude != null && _longitude != null &&
            Geolocator.distanceBetween(
              _latitude!, _longitude!, metadata.latitude!, metadata.longitude!,
            ) > 500;
        if (oldPhoto || takenElsewhere) {
          final usePhoto = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Use the photo location?'),
              content: Text([
                if (oldPhoto)
                  'This photo was taken more than 48 hours ago. Check that the issue is still present.',
                if (takenElsewhere)
                  'The photo was taken more than 500 m from your selected location.',
                'Use its saved location for this incident?',
              ].join('\n\n')),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Keep current location'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Use photo location'),
                ),
              ],
            ),
          );
          if (usePhoto != true || !mounted ||
              requestId != _locationRequestId) {
            return;
          }
        }
        final photoRequestId = ++_locationRequestId;
        setState(() => _isFetchingLocation = true);
        try {
          await _applyFix(
            latitude: metadata.latitude!,
            longitude: metadata.longitude!,
            accuracyMeters: null,
            source: ReportLocationSource.photoExif,
            requestId: photoRequestId,
          );
        } finally {
          if (mounted && photoRequestId == _locationRequestId) {
            setState(() => _isFetchingLocation = false);
          }
        }
      } else if (source == ImageSource.camera) {
        final fix = await cameraFix;
        if (!mounted || requestId != _locationRequestId) return;
        if (fix != null &&
            capturedAt.difference(fix.timestamp).abs() <= const Duration(minutes: 2)) {
          final photoRequestId = ++_locationRequestId;
          setState(() => _isFetchingLocation = true);
          try {
            await _applyFix(
              latitude: fix.latitude,
              longitude: fix.longitude,
              accuracyMeters: fix.accuracyMeters,
              source: ReportLocationSource.cameraGps,
              requestId: photoRequestId,
            );
          } finally {
            if (mounted && photoRequestId == _locationRequestId) {
              setState(() => _isFetchingLocation = false);
            }
          }
        } else {
          showAppSnackBar(context,
            'No recent capture GPS was available. Review the location or pick on map.',
            type: AppMessageType.warning);
        }
      } else {
        showAppSnackBar(context,
          'This photo has no saved GPS. Review your current location or pick on map.',
          type: AppMessageType.warning);
      }
    } on FormatException catch (e) {
      if (mounted) {
        showAppSnackBar(context, e.message, type: AppMessageType.error);
      }
    } catch (e) {
      debugPrint('Image pick failed: $e');
      if (mounted) {
        showAppSnackBar(
          context,
          'Could not prepare this photo. Check permissions or try a JPEG or PNG photo.',
          type: AppMessageType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isPickingPhoto = false);
    }
  }

  Future<LocationFix?> _cameraLocationFix() async {
    try {
      // Do not interrupt the camera with a second permission prompt.
      final availability = await _deviceLocation.checkAvailability(
        requestPermission: false,
      );
      if (availability != LocationAvailability.available) {
        return null;
      }
      return await _deviceLocation.currentFix();
    } catch (e) {
      debugPrint('Camera-associated GPS fix unavailable: $e');
      return null;
    }
  }

  Future<void> _recoverLostPhoto() async {
    setState(() => _isPickingPhoto = true);
    try {
      final response = await _imagePicker.retrieveLostData();
      if (!mounted || response.isEmpty) return;
      if (response.exception != null) throw response.exception!;
      for (final file in response.files ?? <XFile>[]) {
        final photo = await _photoMetadata.prepare(await file.readAsBytes());
        if (!mounted) return;
        _attachPhoto(file, photo);
      }
      if (mounted) {
        showAppSnackBar(
          context,
          'Recovered photos after the camera closed. Review the incident location before submitting.',
          type: AppMessageType.warning,
        );
      }
    } on Exception catch (e) {
      debugPrint('Report photo recovery failed: $e');
      if (mounted) {
        showAppSnackBar(context, 'Could not recover the photo. Please attach it again.',
            type: AppMessageType.error);
      }
    } finally {
      if (mounted) setState(() => _isPickingPhoto = false);
    }
  }

  void _attachPhoto(XFile file, PreparedReportPhoto photo) {
    final upload = _uploads.add(photo.bytes);
    setState(() => _selectedImages.add(PickedImage(
      file: file, bytes: photo.bytes, metadata: photo.metadata, upload: upload,
    )));
  }

  void _removeImage(int index) {
    final photo = _selectedImages.removeAt(index);
    final upload = photo.upload;
    if (upload != null) _uploads.remove(upload);
    setState(() {});
  }

  void _retryPhoto(int index) {
    final upload = _selectedImages[index].upload;
    if (upload != null) _uploads.retry(upload);
  }

  Future<List<String>> _uploadImages() {
    final uploads = _selectedImages.map((image) => image.upload).toList();
    if (uploads.any((upload) => upload == null)) {
      throw const ReportPhotoUploadException('A photo is not ready. Remove and attach it again.');
    }
    return _uploads.waitForUrls(uploads.whereType<ReportPhotoUpload>().toList());
  }

  String? _nullIfEmpty(TextEditingController c) {
    final text = c.text.trim();
    return text.isEmpty ? null : text;
  }

  ReportModel _buildReport({
    required String id,
    required String userId,
    required String userName,
    required DateTime submittedAt,
    List<String>? imageUrls,
  }) {
    final address = _fullAddressController.text.trim();
    final reporterName = _reporterNameController.text.trim();
    final isFinal = imageUrls != null;

    return ReportModel(
      id: id,
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      category: _selectedCategory,
      location: address.isEmpty ? 'Unknown' : address,
      barangay: _nullIfEmpty(_barangayController),
      sitio: _nullIfEmpty(_streetController),
      landmark: _nullIfEmpty(_landmarkController),
      latitude: _latitude,
      longitude: _longitude,
      severity: _severityForCategory(_selectedCategory),
      imageUrl: isFinal && imageUrls.isNotEmpty ? imageUrls.first : null,
      imageUrls: imageUrls ?? const [],
      submittedBy: userId,
      submittedByName: reporterName.isEmpty ? userName : reporterName,
      submittedByContact: _nullIfEmpty(_contactController),
      isAnonymous: false,
      submittedAt: submittedAt,
      statusHistory: isFinal
          ? [
              ReportStatusUpdate(
                status: 'pending',
                message: 'Report submitted successfully.',
                timestamp: DateTime.now(),
              ),
            ]
          : const [],
    );
  }

  Future<void> _submitReport() async {
    if (_isUploadingImages || _isAddingSupport) return;
    if (_isPickingPhoto || _isFetchingLocation) {
      showAppSnackBar(context, 'Wait for the photo and location to finish.',
          type: AppMessageType.warning);
      return;
    }
    if (!_formKey.currentState!.validate()) {
      showAppSnackBar(
        context,
        'Please fix the highlighted fields.',
        type: AppMessageType.warning,
      );
      return;
    }

    if (_latitude == null || _longitude == null) {
      showAppSnackBar(
        context,
        'Please set the incident location using GPS or the map picker.',
        type: AppMessageType.warning,
      );
      return;
    }

    if (_selectedImages.isEmpty) {
      showAppSnackBar(
        context,
        'Please attach at least one photo of the issue.',
        type: AppMessageType.warning,
      );
      return;
    }

    final auth = context.read<app_auth_provider.AuthProvider>();
    final user = auth.user;
    if (user == null) {
      showAppSnackBar(
        context,
        'You must be signed in to submit a report.',
        type: AppMessageType.error,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: _buildPreviewDialog,
    );
    if (confirmed != true || !mounted) return;

    final reportProvider = context.read<ReportProvider>();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _isUploadingImages = true);

    try {
      final tempId = 'r${DateTime.now().millisecondsSinceEpoch}';
      final submittedAt = DateTime.now();

      final nearbyReport = await reportProvider.findNearbyActiveReport(
        _buildReport(
          id: tempId,
          userId: user.id,
          userName: user.name,
          submittedAt: submittedAt,
        ),
      );
      if (nearbyReport != null) {
        await _offerSupport(reportProvider, nearbyReport);
        return;
      }

      final imageUrls = await _uploadImages();
      if (!mounted) return;
      await reportProvider.submitReport(
        _buildReport(
          id: tempId,
          userId: user.id,
          userName: user.name,
          submittedAt: submittedAt,
          imageUrls: imageUrls,
        ),
      );

      if (!mounted) return;
      showAppSnackBar(
        context,
        'Report submitted successfully!',
        type: AppMessageType.success,
        action: SnackBarAction(
          label: 'Track',
          textColor: Colors.white,
          onPressed: _openMySubmissions,
        ),
      );
      _resetForm();
    } on DuplicateReportException catch (e) {
      await _offerSupport(reportProvider, e.existingReport);
    } on ReportPhotoUploadException catch (e) {
      if (mounted) {
        showAppSnackBar(context, e.message, type: AppMessageType.error);
      }
    } catch (e) {
      debugPrint('Report submit failed: $e');
      if (mounted) {
        showAppSnackBar(
          context,
          'Could not submit your report. Check your connection and try again.',
          type: AppMessageType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingImages = false);
    }
  }

  Future<void> _offerSupport(
    ReportProvider provider,
    ReportModel existing,
  ) async {
    if (!mounted) return;
    final wantsToSupport = await _showNearbyReportDialog(existing);
    if (wantsToSupport != true || !mounted) return;
    try {
      await provider.addMeToo(existing.id);
    } catch (e) {
      debugPrint('Nearby report support failed: $e');
      if (mounted) {
        showAppSnackBar(context, 'Could not add support. Please try again.',
            type: AppMessageType.error);
      }
      return;
    }
    if (mounted) {
      showAppSnackBar(
        context,
        'Your support was added to the nearby report.',
        type: AppMessageType.success,
      );
    }
  }

  Future<void> _supportNearby() async {
    final report = _nearby.report;
    if (report == null || _isAddingSupport || _isUploadingImages) return;
    final provider = context.read<ReportProvider>();
    if (context.read<app_auth_provider.AuthProvider>().user == null) {
      showAppSnackBar(context, 'Sign in to support this report.',
          type: AppMessageType.warning);
      return;
    }
    setState(() => _isAddingSupport = true);
    try {
      await _offerSupport(provider, report);
      if (mounted) _checkNearby();
    } catch (e) {
      debugPrint('Adding nearby report support failed: $e');
      if (mounted) {
        showAppSnackBar(context, 'Could not add support. Please try again.',
            type: AppMessageType.error);
      }
    } finally {
      if (mounted) setState(() => _isAddingSupport = false);
    }
  }

  void _resetForm() {
    for (final photo in _selectedImages) {
      if (photo.upload != null) _uploads.remove(photo.upload!);
    }
    _nearby.check(null);
    _titleController.clear();
    _descController.clear();
    _fullAddressController.clear();
    _barangayController.clear();
    _streetController.clear();
    _landmarkController.clear();
    setState(() {
      _selectedCategory = _categories.first;
      _selectedImages.clear();
      _latitude = null;
      _longitude = null;
      _locationSource = ReportLocationSource.unknown;
      _locationAccuracyMeters = null;
      _locationOutsideBoundary = false;
    });
    _formKey.currentState?.reset();
    _autoFetchLocation();
  }

  void _openMySubmissions() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MySubmissionsScreen()),
    );
  }

  Future<bool?> _showNearbyReportDialog(ReportModel report) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('A nearby report already exists'),
        content: Text(
          'There is an active ${report.category.toLowerCase()} report at '
          '${report.location}. Is this the same issue you want to report?\n\n'
          'Choose “Me Too” to increase its priority instead of creating a duplicate.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.thumb_up_outlined),
            label: const Text('Me Too'),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewDialog(BuildContext dialogContext) {
    final photos = _selectedImages.length;
    return AlertDialog(
      title: const Text('Review your report'),
      content: SizedBox(
        width: 430,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              DetailRow(
                label: 'Title',
                value: _titleController.text.trim(),
                labelWidth: 90,
              ),
              DetailRow(
                label: 'Category',
                value: _selectedCategory,
                labelWidth: 90,
              ),
              DetailRow(
                label: 'Barangay',
                value: _barangayController.text.trim(),
                labelWidth: 90,
              ),
              DetailRow(
                label: 'Street',
                value: _streetController.text.trim(),
                labelWidth: 90,
              ),
              DetailRow(
                label: 'Landmark',
                value: _landmarkController.text.trim(),
                labelWidth: 90,
              ),
              DetailRow(
                label: 'Address',
                value: _fullAddressController.text.trim(),
                labelWidth: 90,
              ),
              DetailRow(
                label: 'Description',
                value: _descController.text.trim(),
                labelWidth: 90,
              ),
              DetailRow(
                label: 'Photos',
                value: '$photos attached',
                labelWidth: 90,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Edit'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Submit'),
        ),
      ],
    );
  }

  Future<bool> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard this report?'),
        content: const Text('What you entered so far will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return discard == true;
  }

  Widget _buildNearbyBanner() {
    if (_nearby.isChecking) {
      return const Text(
        'Checking for similar nearby reports...',
        style: TextStyle(fontSize: 13),
      );
    }
    if (_nearby.error != null) {
      return Row(children: [
        Expanded(child: Text(_nearby.error!)),
        TextButton(onPressed: _checkNearby, child: const Text('Retry check')),
      ]);
    }
    final report = _nearby.report;
    if (report == null) return const SizedBox.shrink();
    final distance = _latitude != null && _longitude != null &&
            report.latitude != null && report.longitude != null
        ? Geolocator.distanceBetween(
            _latitude!, _longitude!, report.latitude!, report.longitude!,
          ).round()
        : null;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Similar report${distance == null ? ' nearby' : ' $distance m away'}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(report.title),
          Text(report.location),
          const Text('If this is the same issue, support the existing report instead.'),
          TextButton.icon(
            onPressed: _supportNearby,
            icon: const Icon(Icons.thumb_up_outlined),
            label: const Text('Me Too'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWorking =
        _isUploadingImages ||
        _isAddingSupport ||
        context.select<ReportProvider, bool>((p) => p.isLoading);

    return PopScope(
      canPop: !_hasInput && !isWorking && !_isPickingPhoto,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (isWorking || _isPickingPhoto) {
          showAppSnackBar(context, 'Please wait for the current operation to finish.',
              type: AppMessageType.warning);
          return;
        }
        final navigator = Navigator.of(context);
        if (await _confirmDiscard()) navigator.pop();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Form(
                key: _formKey,
                onChanged: () => setState(() {}),
                child: AbsorbPointer(
                  absorbing: isWorking,
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionHeader(
                            icon: Icons.photo_camera_outlined,
                            label: 'Photo Evidence',
                            subtitle: 'At least one photo is required',
                          ),
                          const SizedBox(height: AppSpacing.md),
                          CustomButton(
                            text: _isPickingPhoto
                                ? 'Preparing photo...'
                                : 'Snap & Report',
                            icon: Icons.photo_camera_outlined,
                            isLoading: _isPickingPhoto,
                            onPressed: isWorking || _isPickingPhoto
                                ? null
                                : () => _pickImage(ImageSource.camera),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.photo_library_outlined),
                            label: const Text('Upload from gallery'),
                            onPressed: isWorking || _isPickingPhoto
                                ? null
                                : () => _pickImage(ImageSource.gallery),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          ReportPhotoStrip(
                            images: _selectedImages,
                            onAdd: () => _pickImage(),
                            onRemove: _removeImage,
                            onRetry: _retryPhoto,
                            enabled: !isWorking && !_isPickingPhoto,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _buildNearbyBanner(),
                    const SizedBox(height: AppSpacing.md),
                    SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionHeader(
                            icon: Icons.assignment_outlined,
                            label: 'Report Details',
                            subtitle: 'Describe the issue clearly',
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          CustomTextField(
                            controller: _titleController,
                            label: 'Report Title',
                            prefixIcon: Icons.title,
                            textInputAction: TextInputAction.next,
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Report title is required'
                                : null,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Semantics(
                            label: 'Report category: $_selectedCategory',
                            enabled: true,
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedCategory,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: 'Category',
                                prefixIcon: Icon(
                                  _categoryIcons[_selectedCategory] ??
                                      Icons.category_outlined,
                                  color: AppColors.textGrey,
                                ),
                              ),
                              items: [
                                for (final category in _categories)
                                  DropdownMenuItem(
                                    value: category,
                                    child: Text(
                                      category,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedCategory = val);
                                  _checkNearby();
                                }
                              },
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          CustomTextField(
                            controller: _descController,
                            label: 'Describe the issue in detail',
                            prefixIcon: Icons.edit_note,
                            maxLines: 4,
                            keyboardType: TextInputType.multiline,
                            validator: (v) => v == null || v.trim().length < 10
                                ? 'Please provide a description (min. 10 characters)'
                                : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ReportLocationCard(
                      barangayController: _barangayController,
                      streetController: _streetController,
                      landmarkController: _landmarkController,
                      addressController: _fullAddressController,
                      isFetching: _isFetchingLocation,
                      hasCoordinates: _latitude != null && _longitude != null,
                      onRefreshGps: _autoFetchLocation,
                      onPickOnMap: _pickOnMap,
                      enabled: !isWorking,
                      source: _locationSource,
                      accuracyMeters: _locationAccuracyMeters,
                      isOutsideBoundary: _locationOutsideBoundary,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionHeader(
                            icon: Icons.person_outline,
                            label: 'Reporter Information',
                            subtitle: 'Prefilled from your account',
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          CustomTextField(
                            controller: _reporterNameController,
                            label: 'Full Name',
                            prefixIcon: Icons.badge_outlined,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.name],
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Full name is required'
                                : null,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          CustomTextField(
                            controller: _contactController,
                            label: 'Contact Number',
                            prefixIcon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [
                              AutofillHints.telephoneNumber,
                            ],
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Contact number is required';
                              }
                              final digitsOnly = v.replaceAll(
                                RegExp(r'[^0-9]'),
                                '',
                              );
                              if (digitsOnly.length < 10) {
                                return 'Enter a valid contact number';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    CustomButton(
                      text: isWorking
                          ? (_isUploadingImages
                              ? 'Finishing report...'
                              : 'Submitting...')
                          : 'Submit Report',
                      onPressed: isWorking || _isPickingPhoto || _isFetchingLocation
                          ? null
                          : _submitReport,
                      icon: Icons.send_rounded,
                      isLoading: isWorking,
                      useGradient: true,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    CustomButton(
                      text: 'Track my reports',
                      onPressed: isWorking || _isPickingPhoto
                          ? null
                          : _openMySubmissions,
                      icon: Icons.track_changes_outlined,
                      isOutlined: true,
                    ),
                  ],
                ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
