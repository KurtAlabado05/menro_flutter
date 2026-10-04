import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_tokens.dart';
import '../../services/map_records_service.dart';
import '../project/project_details_screen.dart';
import '../report/report_details_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key, this.recordsService, this.tileProvider});

  final MapRecordsService? recordsService;
  final TileProvider? tileProvider;

  @override
  State<MapScreen> createState() => _MapScreenState();
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
  MapRecord? _selectedPin;

  final MapController _mapController = MapController();
  late final MapRecordsService _recordsService =
      widget.recordsService ?? MapRecordsService();
  bool _mapReady = false;
  double _zoom = 12;
  static const double _minZoom = 11;
  static const double _maxZoom = 17;
  bool _hasLocationPermission = false;
  LatLng? _myLatLng;

  static final LatLng _defaultCenter = LatLng(14.9545, 120.8995);
  List<MapRecord> _pins = [];
  bool _isLoadingPins = false;
  int _recordsWithoutCoordinates = 0;
  String? _pinLoadError;
  List<LatLng> _baliwagPolygon =
      []; // 🟢 ADDED: Stores high-precision vector nodes

  Future<void> _loadPinsFromFirestore() async {
    if (_isLoadingPins) return;
    setState(() {
      _isLoadingPins = true;
      _pinLoadError = null;
    });

    try {
      final result = await _recordsService.load();
      if (!mounted) return;
      final errors = [
        result.reports.error,
        result.projects.error,
      ].nonNulls.toList();
      setState(() {
        _pins = [...result.reports.records, ...result.projects.records];
        _recordsWithoutCoordinates =
            result.reports.unmappedCount + result.projects.unmappedCount;
        _pinLoadError = errors.isEmpty ? null : errors.join(' ');
        _selectedPin = null;
      });
    } finally {
      if (mounted) setState(() => _isLoadingPins = false);
    }
  }

  List<MapRecord> get _filteredPins {
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

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _changeZoom(double delta) {
    if (!_mapReady) return;
    final target = (_mapController.zoom + delta).clamp(_minZoom, _maxZoom);
    _mapController.move(_mapController.center, target);
  }

  void _selectFilter(String filter) {
    setState(() {
      _activeFilter = filter;
      _selectedPin = null;
    });
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
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;
      final latLng = LatLng(position.latitude, position.longitude);
      setState(() => _myLatLng = latLng);
    } catch (e) {
      debugPrint('MapScreen location error: $e');
    }
  }

  Future<void> _recenterToMyLocation() async {
    if (!_hasLocationPermission || _myLatLng == null) {
      await _initLocation();
    }
    final target = _myLatLng;
    if (!mounted || !_mapReady) return;
    if (target == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your location is unavailable. Enable location access and retry.',
          ),
        ),
      );
      return;
    }
    _mapController.move(target, 15);
  }

  Color _markerColorForPin(MapRecord pin) {
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
                minZoom: _minZoom,
                maxZoom: _maxZoom,
                onMapReady: () {
                  if (mounted) setState(() => _mapReady = true);
                },
                onPositionChanged: (position, _) {
                  final zoom = position.zoom;
                  if (mounted && zoom != null && zoom != _zoom) {
                    setState(() => _zoom = zoom);
                  }
                },
                onTap: (_, __) => setState(() => _selectedPin = null),
              ),
              children: [
                TileLayer(
                  tileProvider: widget.tileProvider,
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
                        color: Colors.blue.withValues(alpha: 0.06),
                        borderColor: Colors.blue.withValues(alpha: 0.6),
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: AppRadius.lgAll,
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                            if (_pinLoadError != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  _pinLoadError!,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: _isLoadingPins
                                    ? null
                                    : _loadPinsFromFirestore,
                                icon: const Icon(Icons.refresh, size: 18),
                                label: Text(
                                  _pinLoadError == null ? 'Refresh' : 'Retry',
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _FilterChip(
                                    label: 'All',
                                    isSelected: _activeFilter == 'All',
                                    onTap: () => _selectFilter('All'),
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: _FilterChip(
                                    label:
                                        'Reports (${_pins.where((pin) => pin.type == 'report').length})',
                                    isSelected: _activeFilter == 'Reports',
                                    onTap: () => _selectFilter('Reports'),
                                    color: AppColors.statusPending,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: _FilterChip(
                                    label:
                                        'Projects (${_pins.where((pin) => pin.type == 'project').length})',
                                    isSelected: _activeFilter == 'Projects',
                                    onTap: () => _selectFilter('Projects'),
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
                                      '$_recordsWithoutCoordinates records cannot be mapped because coordinates are missing or invalid.',
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
                      const SizedBox(height: AppSpacing.md),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _MapControlButton(
                              icon: Icons.add,
                              tooltip: 'Zoom in',
                              onTap: _mapReady && _zoom < _maxZoom
                                  ? () => _changeZoom(1)
                                  : null,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            _MapControlButton(
                              icon: Icons.remove,
                              tooltip: 'Zoom out',
                              onTap: _mapReady && _zoom > _minZoom
                                  ? () => _changeZoom(-1)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
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
                          builder: (_) =>
                              ReportDetailsScreen(reportId: _selectedPin!.id),
                        ),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ProjectDetailsScreen(projectId: _selectedPin!.id),
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
                onPressed: _mapReady ? _recenterToMyLocation : null,
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
      borderRadius: AppRadius.pillAll,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.pillAll,
        child: Container(
          constraints: const BoxConstraints(minHeight: 38),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          decoration: BoxDecoration(borderRadius: AppRadius.pillAll),
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
  final VoidCallback? onTap;

  const _MapControlButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: AppRadius.pillAll,
      clipBehavior: Clip.antiAlias,
      elevation: 3,
      child: IconButton(
        onPressed: onTap,
        style: IconButton.styleFrom(shape: const CircleBorder()),
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
  final MapRecord pin;
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
                      color: color.withValues(alpha: 0.15),
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
                      color: color.withValues(alpha: 0.15),
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
