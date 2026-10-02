import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../models/inspection_application_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/inspection_provider.dart';
import '../../services/cloudinary_image_service.dart';
import '../../widgets/tree_species_identify_sheet.dart';

class TreeIdentificationScreen extends StatefulWidget {
  const TreeIdentificationScreen({super.key});

  @override
  State<TreeIdentificationScreen> createState() =>
      _TreeIdentificationScreenState();
}

class _TreeIdentificationScreenState extends State<TreeIdentificationScreen> {
  static const _cloudinary = CloudinaryImageService(
    cloudName: 'dfo5l4d4t',
    uploadPreset: 'flutter_upload_preset',
  );

  String? _linkedApplicationId;
  double? _latitude;
  double? _longitude;
  double? _accuracy;
  bool _identifying = false;
  bool _capturingLocation = false;
  String? _error;

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
        throw Exception('Location permission is required to tag this tree.');
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Enable location services and try again.');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _accuracy = position.accuracy;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _capturingLocation = false);
    }
  }

  Future<void> _identifyTree(List<InspectionApplicationModel> queue) async {
    final authUser = context.read<AuthProvider>().user;
    final inspectionProvider = context.read<InspectionProvider>();
    if (authUser == null) {
      setState(() => _error = 'Your session has expired. Please sign in again.');
      return;
    }

    setState(() {
      _identifying = true;
      _error = null;
    });
    try {
      final result = await TreeSpeciesIdentifySheet.show(
        context,
        cloudinary: _cloudinary,
      );
      if (result == null || !mounted) return;
      final species = result.bestMatch;
      if (species == null) {
        setState(() => _error = 'No species suggestion was selected.');
        return;
      }

      final linkedApplication = queue
          .where((application) => application.id == _linkedApplicationId)
          .firstOrNull;
      final record = <String, dynamic>{
        'inspectorId': authUser.id,
        'inspectorName': authUser.contextualName,
        'source': 'inspection_officer',
        'identifiedAt': (result.identifiedAt ?? DateTime.now()).toIso8601String(),
        'suggestedScientificName': species.scientificName,
        'suggestedCommonNames': species.commonNames,
        'matchedDropdownLabel': species.matchedDropdownLabel,
        'confidence': species.confidence,
        'userAccepted': true,
        'speciesIdentification': result.toFirestore(userAccepted: true),
        'evidencePhotoUrls': result.evidencePhotoUrls,
        'linkedApplicationId': linkedApplication?.id,
        'linkedApplicationCollection': linkedApplication?.sourceCollection,
        'latitude': _latitude,
        'longitude': _longitude,
        'locationAccuracy': _accuracy,
      };
      final recordId = await inspectionProvider.saveTreeIdentification(record);
      if (!mounted) return;
      debugPrint('Saved tree identification $recordId');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tree identification saved')),
      );
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _identifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final queue = context.watch<InspectionProvider>().queue;
    final inspectorId = context.watch<AuthProvider>().user?.id;
    final selectedApplication = queue
        .where((application) => application.id == _linkedApplicationId)
        .firstOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Tree Identification'),
        backgroundColor: AppColors.primary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.cardWhite,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Site and Application',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                if (queue.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: _linkedApplicationId,
                    decoration: const InputDecoration(
                      labelText: 'Related Application (optional)',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('No linked application'),
                      ),
                      ...queue.map(
                        (application) => DropdownMenuItem(
                          value: application.id,
                          child: Text(
                            '${application.applicantName} · ${application.type}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _linkedApplicationId = value),
                  )
                else
                  const Text(
                    'No forwarded applications available to link.',
                    style: TextStyle(color: AppColors.textGrey, fontSize: 12),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _latitude == null || _longitude == null
                            ? 'Tree location not captured'
                            : 'GPS ${_latitude!.toStringAsFixed(6)}, ${_longitude!.toStringAsFixed(6)}'
                                '${_accuracy == null ? '' : ' · ±${_accuracy!.round()} m'}',
                        style: const TextStyle(
                          color: AppColors.textGrey,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Capture tree location',
                      onPressed: _capturingLocation ? null : _captureLocation,
                      icon: _capturingLocation
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location),
                    ),
                  ],
                ),
                if (selectedApplication != null)
                  Text(
                    'Linked: ${selectedApplication.applicantName}',
                    style: const TextStyle(fontSize: 12, color: AppColors.primary),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _identifying ? null : () => _identifyTree(queue),
            icon: _identifying
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.document_scanner_outlined),
            label: Text(_identifying ? 'Identifying…' : 'Identify a Tree'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Each confirmed result is saved separately, so you can document multiple trees during one visit. AI suggestions should be verified by the inspecting officer.',
            style: TextStyle(fontSize: 12, color: AppColors.textGrey),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Colors.red.shade700)),
          ],
          const SizedBox(height: 20),
          const Text(
            'Saved Identifications',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 8),
          if (inspectorId == null)
            const Text('Sign in to view saved identifications.')
          else
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('inspection_tree_identifications')
                  .where('inspectorId', isEqualTo: inspectorId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text('Could not load saved identifications: ${snapshot.error}');
                }
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final records = snapshot.data!.docs.toList()
                  ..sort((a, b) => (b.data()['identifiedAt'] ?? '').toString().compareTo(
                        (a.data()['identifiedAt'] ?? '').toString(),
                      ));
                if (records.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: Center(
                      child: Text(
                        'No trees identified yet.',
                        style: TextStyle(color: AppColors.textGrey),
                      ),
                    ),
                  );
                }
                return Column(
                  children: records
                      .map((record) => _IdentificationCard(
                            id: record.id,
                            data: record.data(),
                          ))
                      .toList(),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _IdentificationCard extends StatelessWidget {
  final String id;
  final Map<String, dynamic> data;

  const _IdentificationCard({required this.id, required this.data});

  @override
  Widget build(BuildContext context) {
    final commonNames = (data['suggestedCommonNames'] as List? ?? const [])
      .map((name) => name.toString())
      .toList();
    final name = commonNames.isNotEmpty
      ? commonNames.first
      : (data['suggestedScientificName'] ?? data['matchedDropdownLabel'] ?? 'Unknown species').toString();
    final scientificName = (data['suggestedScientificName'] ?? '').toString();
    final confidence = ((data['confidence'] as num?)?.toDouble() ?? 0) * 100;
    final evidence = (data['evidencePhotoUrls'] as List? ?? const [])
      .map((url) => url.toString())
      .toList();

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: ListTile(
        leading: evidence.isEmpty
            ? const CircleAvatar(child: Icon(Icons.park_outlined))
            : ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  evidence.first,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
                ),
              ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${scientificName.isEmpty ? data['matchedDropdownLabel'] ?? '' : scientificName}\n'
          'Confidence ${confidence.round()}% · $id',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: true,
      ),
    );
  }
}
