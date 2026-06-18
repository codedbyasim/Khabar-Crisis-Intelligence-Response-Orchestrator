import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:khabar/theme/language_provider.dart';

class LocationResult {
  final LatLng position;
  final bool isMockedOrOutside;
  final String source; // 'gps', 'ip', or 'default'

  LocationResult({
    required this.position,
    required this.isMockedOrOutside,
    required this.source,
  });
}

class LocationHelper {
  // Pakistan bounding box: lat 23.0 to 37.5, lng 60.0 to 77.5
  static const double minLat = 23.0;
  static const double maxLat = 37.5;
  static const double minLng = 60.0;
  static const double maxLng = 77.5;

  static LatLng getDefaultLocation() {
    final String region = LanguageProvider().region;
    final bool isRawalpindi = region.toLowerCase().contains('rawalpindi');
    return LatLng(
      isRawalpindi ? 33.5651 : 33.6844,
      isRawalpindi ? 73.0169 : 73.0479,
    );
  }

  static bool isInPakistan(double lat, double lng) {
    return lat >= minLat && lat <= maxLat && lng >= minLng && lng <= maxLng;
  }

  /// Attempts to fetch location.
  /// 1. Tries a fresh GPS read first (not stale cached coordinates).
  /// 2. If GPS fails or times out, uses the last known position only as a fallback.
  /// 3. If GPS is unavailable, tries IP-based Geolocation.
  /// 4. Falls back to getDefaultLocation().
  static Future<LocationResult> fetchLocation() async {
    // 1. Try GPS location (skip auto-fetch on Web as browser GPS might be wrong or blocked by CORS)
    if (!kIsWeb) {
      try {
        final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          debugPrint('[LocationHelper] GPS service is disabled.');
        } else {
          LocationPermission permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
          }

          if (permission == LocationPermission.whileInUse ||
              permission == LocationPermission.always) {
            final position = await _getLivePosition();
            if (position != null) {
              debugPrint('[LocationHelper] Live GPS location succeeded: (${position.latitude}, ${position.longitude})');
              return LocationResult(
                position: LatLng(position.latitude, position.longitude),
                isMockedOrOutside: !isInPakistan(position.latitude, position.longitude),
                source: 'gps',
              );
            }

            final lastPosition = await Geolocator.getLastKnownPosition();
            if (lastPosition != null) {
              debugPrint('[LocationHelper] GPS last known position used as fallback: (${lastPosition.latitude}, ${lastPosition.longitude})');
              return LocationResult(
                position: LatLng(lastPosition.latitude, lastPosition.longitude),
                isMockedOrOutside: !isInPakistan(lastPosition.latitude, lastPosition.longitude),
                source: 'gps',
              );
            }
          }
        }
      } catch (e) {
        debugPrint('[LocationHelper] GPS location fetch error: $e');
      }
    }

    // 2. If GPS failed, try IP-based location fallback
    final ipLoc = await fetchIPLocation();
    if (ipLoc != null) {
      return LocationResult(
        position: ipLoc,
        isMockedOrOutside: !isInPakistan(ipLoc.latitude, ipLoc.longitude),
        source: 'ip',
      );
    }

    // 3. Fallback to default
    final defaultLoc = getDefaultLocation();
    debugPrint('[LocationHelper] Falling back to default: (${defaultLoc.latitude}, ${defaultLoc.longitude})');
    return LocationResult(
      position: defaultLoc,
      isMockedOrOutside: true,
      source: 'default',
    );
  }

  static Future<Position?> _getLivePosition() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 15),
        ),
      ).timeout(const Duration(seconds: 15));
      return position;
    } catch (e) {
      debugPrint('[LocationHelper] Live GPS lookup failed: $e');
      return null;
    }
  }

  /// Fetches location using free IP Geolocation APIs
  static Future<LatLng?> fetchIPLocation() async {
    debugPrint('[LocationHelper] Trying IP-based location fallback...');
    // We try multiple APIs for redundancy
    final urls = [
      'https://ipapi.co/json/',
      'https://freeipapi.com/api/json',
    ];

    for (final url in urls) {
      try {
        final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          double? lat;
          double? lng;

          if (url.contains('freeipapi')) {
            lat = data['latitude']?.toDouble();
            lng = data['longitude']?.toDouble();
          } else {
            // ipapi.co
            lat = data['latitude']?.toDouble();
            lng = data['longitude']?.toDouble();
          }

          if (lat != null && lng != null) {
            debugPrint('[LocationHelper] IP Geolocation ($url) succeeded: ($lat, $lng)');
            return LatLng(lat, lng);
          }
        }
      } catch (e) {
        debugPrint('[LocationHelper] IP Geolocation error for $url: $e');
      }
    }
    return null;
  }
}
