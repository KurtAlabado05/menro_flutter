import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/constants/app_colors.dart';
import '../../models/report_location.dart';
import '../../services/geo/baliwag_geo.dart';
import '../../services/geo/reverse_geocoding_service.dart';

class ReportLocationPickerScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  const ReportLocationPickerScreen({
    super.key,
    this.initialLat,
    this.initialLng,
  });

  @override
  State<ReportLocationPickerScreen> createState() =>
      _ReportLocationPickerScreenState();
}

class _ReportLocationPickerScreenState
    extends State<ReportLocationPickerScreen> {
  final MapController _mapController = MapController();
  final ReverseGeocodingService _geocoder = ReverseGeocodingService();
  LatLng? _selected;

  bool _awaitingPreciseTap = false;
  bool _selectedByBarangayButNotTapped = false;
  bool _isDetectingAddress = false;

  LatLng _defaultCenter = BaliwagGeo.defaultCenter;

  /// Populated from [BaliwagGeo.loadPolygon] in [initState]; empty until
  /// then so no point-in-polygon check runs against a stale boundary.
  List<LatLng> _baliwagPolygon = const [];
  String? _detectedAddress;
  String? _detectedLandmark;

  String? _selectedBarangay;
  final TextEditingController _streetController = TextEditingController();
  final TextEditingController _landmarkController = TextEditingController();

  List<String> get _barangays => BaliwagGeo.barangays;

  @override
  void initState() {
    super.initState();
    BaliwagGeo.loadPolygon().then((polygon) {
      if (!mounted) return;
      setState(() => _baliwagPolygon = polygon);

      if (widget.initialLat != null && widget.initialLng != null) {
        final initialPoint = LatLng(widget.initialLat!, widget.initialLng!);
        if (BaliwagGeo.isInside(initialPoint, _baliwagPolygon)) {
          _selected = initialPoint;
          _defaultCenter = initialPoint;
          _tryDetectAddress(_selected!);
        } else {
          _selected = _defaultCenter;
          _tryDetectAddress(_selected!);
        }
      } else {
        _tryUseCurrentLocation();
      }
    });
  }

  @override
  void dispose() {
    _streetController.dispose();
    _landmarkController.dispose();
    super.dispose();
  }

  Future<void> _tryUseCurrentLocation() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      final granted =
          permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
      if (!granted) return;

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;

      final p = LatLng(pos.latitude, pos.longitude);

      if (BaliwagGeo.isInside(p, _baliwagPolygon)) {
        setState(() {
          _defaultCenter = p;
          _selected = p;
          _awaitingPreciseTap = false;
        });
        _tryDetectAddress(p);
      } else {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'You are outside Baliwag. Please select location manually.',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
        setState(() {
          _awaitingPreciseTap = true;
          _selected = null;
          _detectedAddress = null;
          _detectedLandmark = null;
          _selectedBarangay = null;
          _streetController.clear();
        });
      }
    } catch (_) {}
  }

  bool _isGeocoding = false;

  Future<void> _moveToBarangay(String barangay) async {
    setState(() => _isGeocoding = true);
    try {
      LatLng point = BaliwagGeo.barangayCoordinates[barangay] ?? _defaultCenter;
      final searchResult = await _geocoder.search('$barangay,Baliwag,Bulacan');
      if (searchResult != null) {
        final geoPoint = LatLng(searchResult.latitude, searchResult.longitude);
        if (BaliwagGeo.isInside(geoPoint, _baliwagPolygon)) {
          point = geoPoint;
        }
      }

      if (!mounted) return;
      setState(() {
        _selectedByBarangayButNotTapped = true;
        _selectedBarangay = barangay;
        _selected = null;
        _detectedAddress = '$barangay, Baliwag, Bulacan';
        _detectedLandmark = null;
        _streetController.clear();
        _defaultCenter = point;
      });
      _mapController.move(point, 15);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isGeocoding = false);
    }
  }

  Future<void> _tryDetectAddress(LatLng point) async {
    setState(() => _isDetectingAddress = true);
    try {
      final result = await _geocoder.reverseGeocode(
        point.latitude,
        point.longitude,
      );

      if (result != null && mounted) {
        setState(() {
          _detectedAddress = result.displayName;
          _detectedLandmark = result.landmark;

          if (result.landmark != null) {
            _landmarkController.text = result.landmark!;
          } else {
            _landmarkController.clear();
          }

          if (result.road != null) {
            _streetController.text = result.road!;
          } else {
            _streetController.clear();
          }

          // Barangay auto-match: prefer the village/suburb text, fall back
          // to scanning the full display name.
          final found = BaliwagGeo.matchBarangayFromText(result.village) ??
              BaliwagGeo.matchBarangayFromText(result.displayName);
          if (found != null) _selectedBarangay = found;
        });
      } else if (mounted) {
        // Offline/failed lookup: fall back to the nearest known barangay so
        // the form isn't left completely blank.
        setState(() {
          _detectedAddress = null;
          _selectedBarangay = BaliwagGeo.nearestBarangay(point);
        });
      }
    } catch (e) {
      debugPrint('Geocoding Warning: $e');
    } finally {
      if (mounted) {
        setState(() => _isDetectingAddress = false);
      }
    }
  }

  void _onMapTap(LatLng point) {
    if (BaliwagGeo.isInside(point, _baliwagPolygon)) {
      setState(() {
        _selected = point;
        _awaitingPreciseTap = false;
        _selectedByBarangayButNotTapped = false;
        _detectedAddress = null;
        _detectedLandmark = null;
      });
      _tryDetectAddress(point);
    } else {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Selection Restricted: Location is outside Baliwag boundary.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _confirm() {
    if (_selected == null || _isDetectingAddress) return;

    final lat = _selected!.latitude;
    final lng = _selected!.longitude;

    final street = _streetController.text.trim().isEmpty
        ? null
        : _streetController.text.trim();
    final manualLandmark = _landmarkController.text.trim().isEmpty
        ? null
        : _landmarkController.text.trim();

    final fallbackAddress =
        '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
    final address =
        (_detectedAddress != null && _detectedAddress!.trim().isNotEmpty)
        ? _detectedAddress!.trim()
        : fallbackAddress;

    final finalLandmark = manualLandmark ?? _detectedLandmark;

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.place, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 10),
              const Text(
                'Confirm location',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Location details',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  _confirmRow(Icons.location_on_outlined, 'Address', address),
                  const SizedBox(height: 8),
                  _confirmRow(Icons.map_outlined, 'Lat / Lng', fallbackAddress),
                  const SizedBox(height: 8),
                  _confirmRow(
                    Icons.home_work_outlined,
                    'Barangay',
                    _selectedBarangay ?? '-',
                  ),
                  const SizedBox(height: 8),
                  _confirmRow(
                    Icons.add_road,
                    'Street Name',
                    (street ?? '(Not Specified)'),
                  ),
                  const SizedBox(height: 8),
                  _confirmRow(
                    Icons.apartment_outlined,
                    'Nearest Landmark',
                    (finalLandmark ?? '-'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Back'),
            ),
            ElevatedButton(
              onPressed: () {
                final result = ReportLocation(
                  latitude: lat,
                  longitude: lng,
                  address: address,
                  barangay: _selectedBarangay,
                  street: street,
                  landmark: finalLandmark,
                  source: ReportLocationSource.manual,
                );
                Navigator.pop(ctx);
                Navigator.pop(context, result);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Use this location'),
            ),
          ],
        );
      },
    );
  }

  Widget _confirmRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool canConfirm =
        _selected != null &&
        !_selectedByBarangayButNotTapped &&
        !_isDetectingAddress;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick Location'),
        backgroundColor: AppColors.primary,
        actions: [
          TextButton(
            onPressed: canConfirm ? _confirm : null,
            child: Text(
              'Confirm',
              style: TextStyle(
                color: canConfirm ? Colors.white : Colors.white60,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                center: _defaultCenter,
                zoom: 13,
                minZoom: 11,
                maxZoom: 18,
                onTap: (tapPos, point) => _onMapTap(point),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c'],
                  userAgentPackageName: 'com.cenroapp.cenro_application',
                ),
                PolygonLayer(
                  polygons: [
                    Polygon(
                      points: _baliwagPolygon,
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderColor: AppColors.primary,
                      borderStrokeWidth: 3.0,
                    ),
                  ],
                ),
                if (_selected != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        width: 44,
                        height: 44,
                        point: _selected!,
                        builder: (ctx) => const Icon(
                          Icons.location_on,
                          color: AppColors.primaryDark,
                          size: 42,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_selected == null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: const Text(
                        'Tap the map inside the Baliwag boundary to choose the exact location.',
                        style: TextStyle(fontSize: 12, color: Colors.black87),
                      ),
                    ),
                  ),

                if (_isDetectingAddress) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Fetching location details...',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  if (_detectedAddress != null) ...[
                    Text(
                      'Detected address',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _detectedAddress!,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],

                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedBarangay,
                        hint: const Text('Select Barangay'),
                        items: _barangays
                            .map(
                              (b) => DropdownMenuItem(value: b, child: Text(b)),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          _moveToBarangay(v);
                        },
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      height: 48,
                      width: 72,
                      alignment: Alignment.center,
                      child: _isGeocoding
                          ? const CircularProgressIndicator(strokeWidth: 2)
                          : ElevatedButton(
                              onPressed: canConfirm ? _confirm : null,
                              child: const Text('Use'),
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _streetController,
                        decoration: InputDecoration(
                          labelText: 'Street Name',
                          hintText: 'e.g., J.P. Rizal St.',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller:
                            _landmarkController, // <-- Add this line here
                        decoration: InputDecoration(
                          labelText: 'Landmark / Directions (optional)',
                          labelStyle: const TextStyle(fontSize: 13),
                          prefixIcon: const Icon(
                            Icons.pin_drop_outlined,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: _tryUseCurrentLocation,
                      icon: const Icon(Icons.my_location),
                      label: const Text('Use current location'),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selected = null;
                          _detectedAddress = null;
                          _detectedLandmark = null;
                          _selectedBarangay = null;
                          _streetController.clear();
                          _landmarkController.clear();
                        });
                      },
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
