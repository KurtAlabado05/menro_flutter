import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/app_colors.dart';
import '../../models/project_model.dart';
import '../../models/report_model.dart';
import '../project/project_details_screen.dart';
import '../report/report_details_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapPin {
  final String id;
  final String title;
  final String location;
  final double latitude;
  final double longitude;
  final String type; // 'report' | 'project'
  final String? status;
  final String? relatedId;

  _MapPin({
    required this.id,
    required this.title,
    required this.location,
    required this.latitude,
    required this.longitude,
    required this.type,
    this.status,
    this.relatedId,
  });
}

class _MapScreenState extends State<MapScreen> {
  bool _didLoadPins = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoadPins) return;
    _didLoadPins = true;
    _loadPinsFromFirestore();
  }

  String _activeFilter = 'All';
  _MapPin? _selectedPin;

  MapController _mapController = MapController();
  bool _hasLocationPermission = false;
  LatLng? _myLatLng;

  static final LatLng _defaultCenter = LatLng(14.9545, 120.8995);
  static final LatLngBounds _baliwagBounds = LatLngBounds(
    LatLng(14.9100, 120.8400),
    LatLng(15.0100, 120.9600),
  );

  List<_MapPin> _pins = [];
  bool _isLoadingPins = false;
  int _recordsWithoutCoordinates = 0;
  String? _pinLoadError;
  List<LatLng> _baliwagPolygon =
      []; // 🟢 ADDED: Stores high-precision vector nodes

  Future<void> _loadPinsFromFirestore() async {
    if (_isLoadingPins) return;
    setState(() => _isLoadingPins = true);
    setState(() => _pinLoadError = null);

    try {
      final snapshots = await Future.wait([
        FirebaseFirestore.instance.collection('reports').get(),
        FirebaseFirestore.instance.collection('projects').get(),
      ]);

      final pins = <_MapPin>[];
      var recordsWithoutCoordinates = 0;

      for (final doc in snapshots[0].docs) {
        final r = ReportModel.fromFirestore(doc.data(), doc.id);
        final lat = r.latitude;
        final lng = r.longitude;
        if (lat == null || lng == null) {
          recordsWithoutCoordinates++;
          continue;
        }

        pins.add(
          _MapPin(
            id: 'report_${r.id}',
            title: r.title,
            location: r.location,
            latitude: lat,
            longitude: lng,
            type: 'report',
            status: r.status,
            relatedId: r.id,
          ),
        );
      }

      for (final doc in snapshots[1].docs) {
        final p = ProjectModel.fromFirestore(doc.data(), doc.id);
        final lat = p.latitude;
        final lng = p.longitude;
        if (lat == null || lng == null) {
          recordsWithoutCoordinates++;
          continue;
        }

        pins.add(
          _MapPin(
            id: 'project_${p.id}',
            title: p.title,
            location: p.location,
            latitude: lat,
            longitude: lng,
            type: 'project',
            status: p.status,
            relatedId: p.id,
          ),
        );
      }

      pins.sort((a, b) => a.type.compareTo(b.type));

      setState(() {
        _pins = pins;
        _recordsWithoutCoordinates = recordsWithoutCoordinates;
        _selectedPin = null;
      });
    } catch (e) {
      debugPrint('MapScreen load pins error: $e');
      if (mounted) {
        setState(() => _pinLoadError = 'Could not load map records.');
      }
    } finally {
      if (mounted) setState(() => _isLoadingPins = false);
    }
  }

  List<_MapPin> get _filteredPins {
    if (_activeFilter == 'Reports') {
      return _pins.where((p) => p.type == 'report').toList();
    } else if (_activeFilter == 'Projects') {
      return _pins.where((p) => p.type == 'project').toList();
    }
    return _pins;
  }

  @override
  void initState() {
    super.initState();
    _loadOSMBoundary(); // 🟢 ADDED: Async initialization for boundary path assets
    _initLocation();
  }

  // 🟢 ASSET LOADER: Parses boundary data directly for dashboard alignment
  Future<void> _loadOSMBoundary() async {
    try {
      final String response = await rootBundle.loadString(
        'assets/maps/baliwag_boundary.geojson',
      );
      final data = json.decode(response);

      List<LatLng> parsingCoordinates = [];

      if (data['features'] != null && data['features'].isNotEmpty) {
        var geometry = data['features'][0]['geometry'];

        if (geometry['type'] == 'Polygon') {
          var rings = geometry['coordinates'];
          for (var point in rings[0]) {
            parsingCoordinates.add(
              LatLng(point[1].toDouble(), point[0].toDouble()),
            );
          }
        } else if (geometry['type'] == 'MultiPolygon') {
          var polygons = geometry['coordinates'];
          for (var ring in polygons[0][0]) {
            parsingCoordinates.add(
              LatLng(ring[1].toDouble(), ring[0].toDouble()),
            );
          }
        }
      }

      if (parsingCoordinates.isNotEmpty && mounted) {
        setState(() {
          _baliwagPolygon = parsingCoordinates;
        });
      }
    } catch (e) {
      debugPrint("OSM Boundary parsing warning in MapScreen: $e");
    }
  }

  Future<void> _initLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _hasLocationPermission = false;
          _myLatLng = null;
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      final granted =
          permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;

      if (!mounted) return;
      setState(() => _hasLocationPermission = granted);

      if (!granted) return;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;
      final latLng = LatLng(position.latitude, position.longitude);
      final clamped = _clampToBounds(latLng);
      setState(() => _myLatLng = clamped);
    } catch (e) {
      debugPrint('MapScreen location error: $e');
    }
  }

  LatLng _clampToBounds(LatLng point) {
    final sw = _baliwagBounds.southWest;
    final ne = _baliwagBounds.northEast;
    final lat = point.latitude.clamp(sw.latitude, ne.latitude);
    final lng = point.longitude.clamp(sw.longitude, ne.longitude);
    return LatLng(lat, lng);
  }

  Future<void> _recenterToMyLocation() async {
    if (!_hasLocationPermission || _myLatLng == null) {
      await _initLocation();
    }
    final target = _myLatLng;
    if (target == null) return;
    final clamped = _clampToBounds(target);
    _mapController.move(clamped, 15);
  }

  Color _markerColorForPin(_MapPin pin) {
    if (pin.type == 'report') {
      switch (pin.status) {
        case 'resolved':
          return Colors.green;
        case 'verified':
          return Colors.blueAccent;
        default:
          return Colors.orange;
      }
    }
    switch (pin.status) {
      case 'completed':
        return Colors.green;
      case 'ongoing':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  List<Marker> get _markers {
    return _filteredPins
        .map(
          (pin) => Marker(
            width: 42,
            height: 42,
            point: LatLng(pin.latitude, pin.longitude),
            builder: (ctx) => GestureDetector(
              onTap: () => setState(() => _selectedPin = pin),
              child: Icon(
                Icons.location_on,
                color: _markerColorForPin(pin),
                size: 36,
              ),
            ),
          ),
        )
        .toList();
  }

  Color _colorForType(String type, String? status) {
    if (type == 'report') {
      switch (status) {
        case 'resolved':
          return AppColors.statusResolved;
        case 'verified':
          return AppColors.statusVerified;
        default:
          return AppColors.statusPending;
      }
    }
    switch (status) {
      case 'completed':
        return AppColors.statusResolved;
      case 'ongoing':
        return AppColors.statusVerified;
      default:
        return AppColors.statusPending;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                center: _defaultCenter,
                zoom: 12,
                minZoom: 11,
                maxZoom: 17,
                maxBounds: _baliwagBounds,
                onTap: (_, __) => setState(() => _selectedPin = null),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c'],
                  userAgentPackageName: 'com.cenroapp.cenro_application',
                ),
                // ─── Precise Polygon Rendering Layer ────────────────────
                PolygonLayer(
                  polygons: [
                    if (_baliwagPolygon.isNotEmpty)
                      Polygon(
                        points: _baliwagPolygon,
                        color: Colors.blue.withOpacity(0.06),
                        borderColor: Colors.blue.withOpacity(0.6),
                        borderStrokeWidth: 2.5,
                        isFilled: true,
                      ),
                  ],
                ),
                MarkerLayer(markers: _markers),
              ],
            ),

            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.arrow_back),
                              tooltip: 'Back',
                              visualDensity: VisualDensity.compact,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Baliwag environmental map',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: AppColors.textDark,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _pinLoadError ??
                                        (_isLoadingPins
                                            ? 'Loading reports and projects...'
                                            : '${_pins.length} mapped records'),
                                    style: const TextStyle(
                                      color: AppColors.textGrey,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _FilterChip(
                                label: 'All',
                                isSelected: _activeFilter == 'All',
                                onTap: () =>
                                    setState(() => _activeFilter = 'All'),
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _FilterChip(
                                label:
                                    'Reports (${_pins.where((pin) => pin.type == 'report').length})',
                                isSelected: _activeFilter == 'Reports',
                                onTap: () =>
                                    setState(() => _activeFilter = 'Reports'),
                                color: AppColors.statusPending,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _FilterChip(
                                label:
                                    'Projects (${_pins.where((pin) => pin.type == 'project').length})',
                                isSelected: _activeFilter == 'Projects',
                                onTap: () =>
                                    setState(() => _activeFilter = 'Projects'),
                                color: AppColors.statusVerified,
                              ),
                            ),
                          ],
                        ),
                        if (_recordsWithoutCoordinates > 0) ...[
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.info_outline,
                                size: 16,
                                color: AppColors.textGrey,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '$_recordsWithoutCoordinates records cannot be mapped because coordinates are missing.',
                                  style: const TextStyle(
                                    color: AppColors.textGrey,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),

            Positioned(
              top: 205,
              right: 16,
              child: Column(
                children: [
                  _MapControlButton(
                    icon: Icons.add,
                    tooltip: 'Zoom in',
                    onTap: () => _mapController.move(
                      _mapController.center,
                      (_mapController.zoom + 1).clamp(11, 17),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _MapControlButton(
                    icon: Icons.remove,
                    tooltip: 'Zoom out',
                    onTap: () => _mapController.move(
                      _mapController.center,
                      (_mapController.zoom - 1).clamp(11, 17),
                    ),
                  ),
                ],
              ),
            ),

            if (_selectedPin != null)
              Positioned(
                bottom: 24,
                left: 16,
                right: 16,
                child: _PinDetailCard(
                  pin: _selectedPin!,
                  color: _colorForType(
                    _selectedPin!.type,
                    _selectedPin!.status,
                  ),
                  onClose: () => setState(() => _selectedPin = null),
                  onTap: () {
                    if (_selectedPin?.type == 'report') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ReportDetailsScreen(
                            reportId: _selectedPin!.relatedId!,
                          ),
                        ),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProjectDetailsScreen(
                            projectId: _selectedPin!.relatedId!,
                          ),
                        ),
                      );
                    }
                  },
                ),
              ),

            Positioned(
              right: 16,
              bottom: _selectedPin == null ? 24 : 140,
              child: FloatingActionButton(
                heroTag: 'my_location_btn',
                onPressed: _recenterToMyLocation,
                child: const Icon(Icons.my_location),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color color;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? color.withValues(alpha: 0.12) : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(minHeight: 38),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected
                  ? color.withValues(alpha: 0.35)
                  : Colors.transparent,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? color : AppColors.textGrey,
            ),
          ),
        ),
      ),
    );
  }
}

class _MapControlButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _MapControlButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 3,
      child: IconButton(
        onPressed: onTap,
        tooltip: tooltip,
        icon: Icon(icon, color: AppColors.textDark),
      ),
    );
  }
}

class _MapLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: const Row(
        children: [
          _LegendDot(color: AppColors.statusPending, label: 'Reports'),
          SizedBox(width: 10),
          _LegendDot(color: AppColors.statusVerified, label: 'Projects'),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.location_on, size: 15, color: color),
        const SizedBox(width: 3),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

class _PinDetailCard extends StatelessWidget {
  final _MapPin pin;
  final Color color;
  final VoidCallback onClose;
  final VoidCallback onTap;

  const _PinDetailCard({
    required this.pin,
    required this.color,
    required this.onClose,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      pin.type == 'report'
                          ? Icons.report_outlined
                          : Icons.nature_outlined,
                      color: color,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pin.title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 12,
                              color: Colors.grey[500],
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                pin.location,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      pin.type == 'report' ? 'Report' : 'Project',
                      style: TextStyle(
                        fontSize: 11,
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      (pin.status ?? '').toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Tap to view details',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 10,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
