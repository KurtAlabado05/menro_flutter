import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/app_colors.dart';
import 'package:flutter/services.dart' show rootBundle;

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
  LatLng? _selected;

  bool _awaitingPreciseTap = false;
  bool _selectedByBarangayButNotTapped = false;
  bool _isDetectingAddress = false;

  LatLng _defaultCenter = const LatLng(14.9545, 120.8995);
  String? _detectedAddress;
  String? _detectedLandmark;

  String? _selectedBarangay;
  final TextEditingController _streetController = TextEditingController();
  final TextEditingController _landmarkController = TextEditingController();

  // ─── Baliwag Precise Polygon Borders ──────────────────────────────────
  // 🟢 CHANGED: Removed 'final const' to allow GeoJSON updates.
  // This list now serves as a high-precision local fallback.
  List<LatLng> _baliwagPolygon = [
    LatLng(14.9602, 120.8521),
    LatLng(14.9714, 120.8535),
    LatLng(14.9772, 120.8614),
    LatLng(14.9865, 120.8641),
    LatLng(14.9951, 120.8722),
    LatLng(14.9991, 120.8842),
    LatLng(14.9982, 120.8991),
    LatLng(14.9911, 120.9115),
    LatLng(14.9856, 120.9192),
    LatLng(14.9821, 120.9311),
    LatLng(14.9744, 120.9395),
    LatLng(14.9612, 120.9412),
    LatLng(14.9498, 120.9381),
    LatLng(14.9415, 120.9295),
    LatLng(14.9312, 120.9211), // Hugs the Angat River border separating Bustos
    LatLng(14.9285, 120.9134),
    LatLng(14.9291, 120.9032),
    LatLng(14.9332, 120.8971),
    LatLng(14.9328, 120.8912),
    LatLng(14.9365, 120.8841), // Slices directly above Plaridel line
    LatLng(14.9351, 120.8765),
    LatLng(14.9311, 120.8711),
    LatLng(14.9412, 120.8631),
    LatLng(14.9445, 120.8692),
    LatLng(14.9491, 120.8681),
    LatLng(14.9515, 120.8612),
    LatLng(14.9561, 120.8545),
  ];

  final Map<String, LatLng> _barangayCoordinates = const {
    'Bagong Nayon': LatLng(14.9590, 120.8940),
    'Barangca': LatLng(14.9350, 120.9150),
    'Calantipay': LatLng(14.9850, 120.9100),
    'Catulinan': LatLng(14.9920, 120.8900),
    'Concepcion': LatLng(14.9510, 120.8910),
    'Hinukay': LatLng(14.9780, 120.9320),
    'Makinabang': LatLng(14.9320, 120.8850),
    'Matangtubig': LatLng(14.9680, 120.9300),
    'Pagala': LatLng(14.9650, 120.8990),
    'Paitan': LatLng(14.9850, 120.8800),
    'Piel': LatLng(14.9720, 120.9150),
    'Pinagbarilan': LatLng(14.9450, 120.8750),
    'Poblacion': LatLng(14.9545, 120.8995),
    'Sabang': LatLng(14.9680, 120.9100),
    'San Jose': LatLng(14.9570, 120.8850),
    'San Roque': LatLng(14.9480, 120.9020),
    'Santa Barbara': LatLng(14.9480, 120.8920),
    'Santo Cristo': LatLng(14.9520, 120.9050),
    'Santo Niño': LatLng(14.9580, 120.8920),
    'Subic': LatLng(14.9560, 120.8840),
    'Sulivan': LatLng(14.9380, 120.9020),
    'Tangos': LatLng(14.9620, 120.8850),
    'Tarcan': LatLng(14.9410, 120.8880),
    'Tiaong': LatLng(14.9360, 120.8720),
    'Tibag': LatLng(14.9650, 120.8750),
    'Tilapayong': LatLng(14.9880, 120.9000),
    'Virgen delas Flores': LatLng(14.9610, 120.9080),
  };

  final List<String> _barangays = [
    'Bagong Nayon',
    'Barangca',
    'Calantipay',
    'Catulinan',
    'Concepcion',
    'Hinukay',
    'Makinabang',
    'Matangtubig',
    'Pagala',
    'Paitan',
    'Piel',
    'Pinagbarilan',
    'Poblacion',
    'Sabang',
    'San Jose',
    'San Roque',
    'Santa Barbara',
    'Santo Cristo',
    'Santo Niño',
    'Subic',
    'Sulivan',
    'Tangos',
    'Tarcan',
    'Tiaong',
    'Tibag',
    'Tilapayong',
    'Virgen delas Flores',
  ];

  @override
  void initState() {
    super.initState();
    _loadOSMBoundary().then((_) {
      // Run your normal initialization checks after boundary details resolve
      if (widget.initialLat != null && widget.initialLng != null) {
        final initialPoint = LatLng(widget.initialLat!, widget.initialLng!);
        if (_isPointInPolygon(initialPoint, _baliwagPolygon)) {
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

  // 🟢 ADD THIS METHOD: Dynamically reads high-fidelity vector nodes from OSM GeoJSON
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
      debugPrint(
        "OSM Boundary parsing warning (Using static fallback fallback): $e",
      );
    }
  }

  @override
  void dispose() {
    _streetController.dispose();
    _landmarkController.dispose();
    super.dispose();
  }

  bool _isPointInPolygon(LatLng point, List<LatLng> polygon) {
    int i, j = polygon.length - 1;
    bool inside = false;
    double x = point.longitude;
    double y = point.latitude;

    for (i = 0; i < polygon.length; i++) {
      if ((polygon[i].latitude < y && polygon[j].latitude >= y ||
              polygon[j].latitude < y && polygon[i].latitude >= y) &&
          (polygon[i].longitude <= x || polygon[j].longitude <= x)) {
        if (polygon[i].longitude +
                (y - polygon[i].latitude) /
                    (polygon[j].latitude - polygon[i].latitude) *
                    (polygon[j].longitude - polygon[i].longitude) <
            x) {
          inside = !inside;
        }
      }
      j = i;
    }
    return inside;
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

      if (_isPointInPolygon(p, _baliwagPolygon)) {
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
      LatLng point = _barangayCoordinates[barangay] ?? _defaultCenter;
      try {
        final url = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=$barangay,Baliwag,Bulacan&format=json&limit=1',
        );
        final response = await http.get(
          url,
          headers: {'User-Agent': 'CenroApp_LocationPicker'},
        );
        if (response.statusCode == 200) {
          final List results = json.decode(response.body);
          if (results.isNotEmpty) {
            final lat = double.parse(results[0]['lat']);
            final lon = double.parse(results[0]['lon']);
            final geoPoint = LatLng(lat, lon);
            if (_isPointInPolygon(geoPoint, _baliwagPolygon)) {
              point = geoPoint;
            }
          }
        }
      } catch (_) {}

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
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=${point.latitude}&lon=${point.longitude}',
      );

      final response = await http
          .get(
            url,
            headers: {'User-Agent': 'CenroApp_LocationPicker_Application'},
          )
          .timeout(const Duration(seconds: 7));

      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        final String? displayName = data['display_name'];
        final addressMap = data['address'] as Map<String, dynamic>?;

        if (displayName != null && displayName.isNotEmpty) {
          setState(() {
            _detectedAddress = displayName;

            if (addressMap != null) {
              // 1. Landmark Parsing
              // 🟢 FIX: Added 'shop' and 'office' to catch commercial landmarks like 7-Eleven or Cafes
              final candidateLandmark =
                  addressMap['amenity'] ??
                  addressMap['building'] ??
                  addressMap['shop'] ?? // <-- Add this
                  addressMap['office'] ?? // <-- Add this
                  addressMap['historic'] ??
                  addressMap['tourism'] ??
                  addressMap['industrial'];
              _detectedLandmark = candidateLandmark?.toString();

              if (_detectedLandmark != null) {
                _landmarkController.text = _detectedLandmark!;
              } else {
                _landmarkController.clear();
              }

              // 2. Fetch Street
              final candidateStreet = addressMap['road'];
              if (candidateStreet != null) {
                _streetController.text = candidateStreet.toString();
              } else {
                _streetController.clear();
              }

              // 3. Barangay Auto-Match
              final String villageData =
                  (addressMap['village'] ??
                          addressMap['suburb'] ??
                          addressMap['neighbourhood'] ??
                          '')
                      .toString();

              final found = _barangays.firstWhere(
                (b) =>
                    villageData.toLowerCase().contains(b.toLowerCase()) ||
                    displayName.toLowerCase().contains(b.toLowerCase()),
                orElse: () => '',
              );
              if (found.isNotEmpty) _selectedBarangay = found;
            }
          });
        }
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
    if (_isPointInPolygon(point, _baliwagPolygon)) {
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
                  color: AppColors.primary.withOpacity(0.10),
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
                final result = {
                  'lat': lat,
                  'lng': lng,
                  'address': address,
                  'barangay': _selectedBarangay,
                  'street': street,
                  'landmark': finalLandmark,
                };
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
                      color: AppColors.primary.withOpacity(0.08),
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
                          color: AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
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
                        value: _selectedBarangay,
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
