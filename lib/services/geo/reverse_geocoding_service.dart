import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

/// Structured address details returned by [ReverseGeocodingService].
class GeocodeAddress {
  const GeocodeAddress({
    required this.displayName,
    this.road,
    this.landmark,
    this.village,
  });

  /// Full human-readable address as returned by the geocoder.
  final String displayName;

  /// Street / road name, when the geocoder identified one.
  final String? road;

  /// Nearest notable place (amenity, shop, building, ...), when present.
  final String? landmark;

  /// Village / suburb / neighbourhood text, used to match against the known
  /// Baliwag barangay list via `BaliwagGeo.matchBarangayFromText`.
  final String? village;
}

/// A coordinate pair returned by a forward-geocoding (place name -> lat/lng)
/// lookup.
class GeocodeCoordinates {
  const GeocodeCoordinates(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}

/// Single Nominatim (OpenStreetMap)-backed geocoder shared by the report
/// screen's GPS auto-fill and the map picker, so both paths resolve the same
/// coordinates to the same address instead of drifting apart.
///
/// Results are cached in memory for the lifetime of the instance: reverse
/// lookups by coordinates rounded to ~11m, forward lookups by the literal
/// query string. This keeps repeated lookups (e.g. re-fetching GPS) fast and
/// friendly to Nominatim's usage policy (max ~1 request/second, no bursts).
class ReverseGeocodingService {
  ReverseGeocodingService({http.Client? client}) : _client = client ?? http.Client();

  static const _userAgent = 'CenroApp_LocationService';
  static const _requestTimeout = Duration(seconds: 7);
  static Future<void> _requestQueue = Future.value();
  static DateTime? _lastRequest;

  final http.Client _client;
  final Map<String, GeocodeAddress?> _reverseCache = {};
  final Map<String, GeocodeCoordinates?> _searchCache = {};

  String _reverseCacheKey(double lat, double lng) =>
      '${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)}';

  Future<http.Response> _get(Uri url) async {
    final previous = _requestQueue;
    final released = Completer<void>();
    _requestQueue = released.future;
    await previous;
    try {
      final last = _lastRequest;
      if (last != null) {
        final wait = const Duration(seconds: 1) - DateTime.now().difference(last);
        if (wait > Duration.zero) await Future<void>.delayed(wait);
      }
      _lastRequest = DateTime.now();
      return await _client
          .get(url, headers: const {'User-Agent': _userAgent})
          .timeout(_requestTimeout);
    } finally {
      released.complete();
    }
  }

  /// Reverse-geocodes [lat]/[lng] into an address. Returns null if the
  /// lookup fails or the geocoder has no data for that point; callers should
  /// fall back to raw coordinates and/or `BaliwagGeo.nearestBarangay`.
  Future<GeocodeAddress?> reverseGeocode(double lat, double lng) async {
    final key = _reverseCacheKey(lat, lng);
    if (_reverseCache.containsKey(key)) return _reverseCache[key];

    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lng',
      );
      final response = await _get(url);

      if (response.statusCode != 200) {
        throw http.ClientException('Reverse geocoding HTTP ${response.statusCode}', url);
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final displayName = data['display_name'] as String?;
      if (displayName == null || displayName.isEmpty) {
        return _reverseCache[key] = null;
      }

      final address = data['address'] as Map<String, dynamic>?;
      // Landmark candidates in priority order: amenity/building/shop/office
      // cover most commercial or civic points of interest Nominatim tags.
      final landmark = address == null
          ? null
          : (address['amenity'] ??
                  address['building'] ??
                  address['shop'] ??
                  address['office'] ??
                  address['historic'] ??
                  address['tourism'] ??
                  address['industrial'])
              ?.toString();
      final road = address?['road']?.toString();
      final village = (address?['village'] ??
              address?['suburb'] ??
              address?['neighbourhood'])
          ?.toString();

      return _reverseCache[key] = GeocodeAddress(
        displayName: displayName,
        road: road,
        landmark: landmark,
        village: village,
      );
    } on Exception catch (e) {
      debugPrint('Reverse geocoding unavailable: $e');
      return null;
    }
  }

  /// Forward-geocodes a free-text [query] (e.g. "Poblacion,Baliwag,Bulacan")
  /// into coordinates. Returns null if nothing is found or the request
  /// fails.
  Future<GeocodeCoordinates?> search(String query) async {
    if (_searchCache.containsKey(query)) return _searchCache[query];

    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeQueryComponent(query)}&format=json&limit=1',
      );
      final response = await _get(url);

      if (response.statusCode != 200) {
        throw http.ClientException('Location search HTTP ${response.statusCode}', url);
      }

      final results = json.decode(response.body) as List;
      if (results.isEmpty) return _searchCache[query] = null;

      final lat = double.tryParse(results[0]['lat'].toString());
      final lon = double.tryParse(results[0]['lon'].toString());
      if (lat == null || lon == null) return _searchCache[query] = null;

      return _searchCache[query] = GeocodeCoordinates(lat, lon);
    } on Exception catch (e) {
      debugPrint('Location search unavailable: $e');
      return null;
    }
  }
}
