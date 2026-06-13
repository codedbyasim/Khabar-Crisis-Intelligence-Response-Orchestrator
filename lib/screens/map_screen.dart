import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:khabar/theme/app_colors.dart';
import 'package:khabar/theme/language_provider.dart';
import 'package:khabar/api_config.dart';
import 'package:geolocator/geolocator.dart';
import 'package:khabar/utils/connectivity_service.dart';
import 'package:khabar/utils/location_helper.dart';
import 'package:khabar/utils/web_helper.dart';

class MapIncident {
  final String id;
  final String title;
  final String urduTitle;
  final String romanUrduTitle;
  final LatLng position;
  final String severity; // P1 CRISIS, P3 URGENT, P5 NORMAL
  final String location;
  final String urduLocation;
  final String responsePlanHeader;
  final String urduResponsePlanHeader;
  final List<ResponseStep> steps;

  MapIncident({
    required this.id,
    required this.title,
    required this.urduTitle,
    required this.romanUrduTitle,
    required this.position,
    required this.severity,
    required this.location,
    required this.urduLocation,
    required this.responsePlanHeader,
    required this.urduResponsePlanHeader,
    required this.steps,
  });
}

class ResponseStep {
  final String title;
  final String urduTitle;
  final String subtitle;
  final String urduSubtitle;

  ResponseStep({
    required this.title,
    required this.urduTitle,
    required this.subtitle,
    required this.urduSubtitle,
  });
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late GoogleMapController mapController;
  MapType _currentMapType = MapType.normal;
  final TextEditingController _searchController = TextEditingController();

  // Islamabad Blue Area center coordinates matching reference UI area
  final LatLng _islamabadCenter = const LatLng(33.7182, 73.0605);

  MapIncident? _selectedIncident;
  bool _isLoadingSearch = false;

  // Filter states
  bool _showConstructionMarkers = true;
  bool _showCrisisMarkers = true;
  double _searchRadius = 5.0; // in km

  // Custom searched marker if any
  Marker? _searchedMarker;

  List<MapIncident> _realIncidents = [];
  List<dynamic> _realResources = [];
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    // No default incident loaded directly on the map card, start clean!
    _selectedIncident = null;
    _fetchRealIncidents();
    _fetchRealResources();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    try {
      final result = await LocationHelper.fetchLocation();
      if (mounted) {
        setState(() {
          // Convert LatLng back to Position object for compatibility
          _currentPosition = Position(
            latitude: result.position.latitude,
            longitude: result.position.longitude,
            timestamp: DateTime.now(),
            accuracy: 0.0,
            altitude: 0.0,
            heading: 0.0,
            speed: 0.0,
            speedAccuracy: 0.0,
            altitudeAccuracy: 0.0,
            headingAccuracy: 0.0,
          );
        });
        debugPrint('[GPS] Map screen user location resolved to (${result.position.latitude}, ${result.position.longitude}) via source: ${result.source}');
      }
    } catch (e) {
      debugPrint("Map screen GPS error: $e");
    }
  }

  Future<void> _fetchRealResources() async {
    try {
      final url = '${ApiConfig.baseUrl}/resources';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _realResources = data['resources'] ?? [];
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching map resources: $e');
    }
  }

  Future<void> _fetchRealIncidents() async {
    try {
      final url = '${ApiConfig.baseUrl}/incidents';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List list = data['incidents'] ?? [];
        final List<MapIncident> loaded = [];

        for (var item in list) {
          final loc = item['location'];
          if (loc == null || loc['lat'] == null || loc['lng'] == null) continue;
          
          final double lat = (loc['lat'] as num).toDouble();
          final double lng = (loc['lng'] as num).toDouble();
          final String title = item['incident_type'] ?? 'Emergency Report';
          final String priority = item['priority'] ?? 'P1';
          final String status = item['status'] ?? 'Active';
          final String address = loc['address'] ?? 'Islamabad';
          final String id = item['incident_id'] ?? 'KH-000';

          final List<ResponseStep> steps = [];
          final List<dynamic>? traces = item['traces'];
          if (traces != null && traces.isNotEmpty) {
            for (var trace in traces) {
              steps.add(ResponseStep(
                title: trace.toString(),
                urduTitle: 'سسٹم اپ ڈیٹ',
                subtitle: 'Processed by Agent Pipeline',
                urduSubtitle: 'ایجنٹ پائپ لائن',
              ));
            }
          } else {
            steps.add(ResponseStep(
              title: 'Incident reported and locked into queue.',
              urduTitle: 'ہنگامی صورتحال رپورٹ درج کر لی گئی ہے۔',
              subtitle: 'Status: $status',
              urduSubtitle: 'حیثیت: $status',
            ));
          }

          loaded.add(MapIncident(
            id: id,
            title: title,
            urduTitle: 'ہنگامی صورتحال الرٹ',
            romanUrduTitle: 'Incident $id',
            position: LatLng(lat, lng),
            severity: '$priority $status',
            location: address,
            urduLocation: address,
            responsePlanHeader: 'Multi-Agent Strategy',
            urduResponsePlanHeader: 'ایجنٹ جوابی منصوبہ',
            steps: steps,
          ));
        }

        setState(() {
          _realIncidents = loaded;
        });
      }
    } catch (e) {
      debugPrint('Error fetching map incidents: $e');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  MapIncident _getDefaultIncident() {
    return MapIncident(
      id: 'KH-201',
      title: 'Major Road Sinkhole',
      urduTitle: 'سڑک کا بڑا گڑھا',
      romanUrduTitle: 'Sarak Ka Bara Garha',
      position: const LatLng(33.7220, 73.0580),
      severity: 'P1 CRISIS',
      location: 'Jinnah Avenue, Blue Area',
      urduLocation: 'جناح ایونیو، بلیو ایریا',
      responsePlanHeader: 'Automated Response Plan',
      urduResponsePlanHeader: 'خودکار جوابی منصوبہ',
      steps: [
        ResponseStep(
          title: 'Reroute traffic to 7th Avenue',
          urduTitle: 'ٹریفک کو سیونتھ ایونیو کی طرف موڑیں',
          subtitle: 'Traffic wardens dispatched.',
          urduSubtitle: 'ٹریفک وارڈن روانہ کر دیے گئے ہیں۔',
        ),
        ResponseStep(
          title: 'Deploy CDA maintenance crew',
          urduTitle: 'سی ڈی اے کی مرمتی ٹیم تعینات کریں',
          subtitle: 'ETA: 15 mins',
          urduSubtitle: 'توقع: 15 منٹ',
        ),
      ],
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  // 🔎 Perform premium geocoding using quick-match local list or openstreetmap Nominatim geocoding (free & unlimited)
  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoadingSearch = true;
    });

    final String normalized = query.toLowerCase();
    LatLng? targetLatLng;
    String locationName = query;
    String urduLocationName = query;

    // 1. First check our local high-speed dictionary — Islamabad & Rawalpindi only
    if (normalized == 'islamabad') {
      targetLatLng = const LatLng(33.6844, 73.0479);
      locationName = 'Islamabad Capital City';
      urduLocationName = 'اسلام آباد وفاقی دارالحکومت';
    } else if (normalized == 'rawalpindi' || normalized == 'rwp') {
      targetLatLng = const LatLng(33.5651, 73.0169);
      locationName = 'Rawalpindi, Punjab';
      urduLocationName = 'راولپنڈی، پنجاب';
    } else if (normalized == 'blue area' || normalized == 'jinnah avenue') {
      targetLatLng = const LatLng(33.7220, 73.0580);
      locationName = 'Jinnah Avenue, Blue Area, Islamabad';
      urduLocationName = 'جناح ایونیو، بلیو ایریا، اسلام آباد';
    } else if (normalized == 'g-10' || normalized == 'g10') {
      targetLatLng = const LatLng(33.6938, 73.0551);
      locationName = 'G-10 Markaz, Islamabad';
      urduLocationName = 'جی-دس مرکز، اسلام آباد';
    } else if (normalized == 'g-11' || normalized == 'g11') {
      targetLatLng = const LatLng(33.7015, 73.0400);
      locationName = 'G-11, Islamabad';
      urduLocationName = 'جی-گیارہ، اسلام آباد';
    } else if (normalized == 'f-7' || normalized == 'f7') {
      targetLatLng = const LatLng(33.7245, 73.0629);
      locationName = 'F-7, Islamabad';
      urduLocationName = 'ایف-سات، اسلام آباد';
    } else if (normalized == 'f-8' || normalized == 'f8') {
      targetLatLng = const LatLng(33.7180, 73.0530);
      locationName = 'F-8, Islamabad';
      urduLocationName = 'ایف-آٹھ، اسلام آباد';
    } else if (normalized == 'saddar' || normalized == 'saddar rawalpindi') {
      targetLatLng = const LatLng(33.5980, 73.0489);
      locationName = 'Saddar, Rawalpindi';
      urduLocationName = 'صدر، راولپنڈی';
    } else if (normalized == 'murree road') {
      targetLatLng = const LatLng(33.6105, 73.0783);
      locationName = 'Murree Road, Rawalpindi';
      urduLocationName = 'مری روڈ، راولپنڈی';
    } else if (normalized == 'nullah lai') {
      targetLatLng = const LatLng(33.6200, 73.0700);
      locationName = 'Nullah Lai, Rawalpindi';
      urduLocationName = 'نالہ لئی، راولپنڈی';
    } else if (normalized == 'faizabad') {
      targetLatLng = const LatLng(33.6601, 73.0789);
      locationName = 'Faizabad Interchange';
      urduLocationName = 'فیض آباد انٹرچینج';
    } else if (normalized == 'bahria town' || normalized == 'bahria') {
      targetLatLng = const LatLng(33.5300, 72.9800);
      locationName = 'Bahria Town, Rawalpindi';
      urduLocationName = 'بحریہ ٹاؤن، راولپنڈی';
    } else if (normalized == 'dha' || normalized == 'dha rawalpindi') {
      targetLatLng = const LatLng(33.5500, 73.1000);
      locationName = 'DHA, Rawalpindi';
      urduLocationName = 'ڈی ایچ اے، راولپنڈی';
    }

    // 2. If not found in local quick list, fetch real-time location via Google Maps Geocoding API on backend
    if (targetLatLng == null) {
      try {
        final response = await http.get(
          Uri.parse('${ApiConfig.baseUrl}/geocode?query=${Uri.encodeComponent(query)}'),
        ).timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['success'] == true) {
            final double lat = (data['lat'] as num).toDouble();
            final double lon = (data['lng'] as num).toDouble();
            targetLatLng = LatLng(lat, lon);
            locationName = data['display_name'] ?? '$query, Pakistan';
            urduLocationName = locationName;
          }
        }
      } catch (e) {
        debugPrint('Geocoding error: $e');
      }
    }

    setState(() {
      _isLoadingSearch = false;
    });

    if (targetLatLng != null) {
      // Smoothly animate Google Map camera to the searched coordinate if online
      if (ConnectivityService().value) {
        mapController.animateCamera(
          CameraUpdate.newLatLngZoom(targetLatLng, 14.5),
        );
      }

      // Setup a dynamic marker for this searched location
      setState(() {
        _searchedMarker = Marker(
          markerId: const MarkerId('searched_location'),
          position: targetLatLng!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
          infoWindow: InfoWindow(
            title: locationName,
            snippet: 'Active Monitoring Zone',
          ),
        );

        // Dynamically update the bottom panel display for this zone
        _selectedIncident = MapIncident(
          id: 'KH-SRCH',
          title: 'Active Monitoring Zone',
          urduTitle: 'سرگرم مانیٹرنگ زون',
          romanUrduTitle: 'Active Monitoring Zone',
          position: targetLatLng,
          severity: 'P5 NORMAL',
          location: locationName,
          urduLocation: urduLocationName,
          responsePlanHeader: 'System Status Feed',
          urduResponsePlanHeader: 'سسٹم کی حیثیت',
          steps: [
            ResponseStep(
              title: 'Telemetry monitoring active',
              urduTitle: 'ٹیلی میٹری کی نگرانی فعال ہے',
              subtitle: 'No crisis markers reported in this area.',
              urduSubtitle: 'اس علاقے میں کوئی ہنگامی صورتحال رپورٹ نہیں ہوئی۔',
            ),
            ResponseStep(
              title: 'Local emergency services stand-by',
              urduTitle: 'مقامی ہنگامی خدمات الرٹ پر ہیں',
              subtitle: 'Response Plan operational.',
              urduSubtitle: 'جوابی منصوبہ فعال ہے۔',
            ),
          ],
        );
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Centered map to: $locationName'),
            backgroundColor: kPrimaryTeal,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Location not found. Try: "G-10", "Saddar", "Murree Road", "Faizabad", "Blue Area", or "Bahria Town".'),
            backgroundColor: kEmergencyRed,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Set<Marker> _createMarkers() {
    final markers = <Marker>{};

    // 1. Add User's Real Location Marker (Blue Dot)
    if (_currentPosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('user_real_location'),
          position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          infoWindow: const InfoWindow(
            title: "My Location",
            snippet: "Live GPS Active",
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    }

    // 2. Add dynamic Backend Resources (Ambulances, Fire Trucks, Rescue Teams)
    for (var r in _realResources) {
      final loc = r['location'];
      if (loc != null && loc['lat'] != null && loc['lng'] != null) {
        final double lat = (loc['lat'] as num).toDouble();
        final double lng = (loc['lng'] as num).toDouble();
        
        final String type = r['resource_type'] ?? 'Unknown';
        final String status = r['status'] ?? 'available';
        final String resId = r['resource_id'] ?? DateTime.now().millisecondsSinceEpoch.toString();
        
        double hue = BitmapDescriptor.hueViolet;
        if (type.toLowerCase() == 'ambulance') {
          hue = BitmapDescriptor.hueRose;
        } else if (type.toLowerCase() == 'fire_truck') {
          hue = BitmapDescriptor.hueOrange;
        } else if (type.toLowerCase() == 'rescue_team') {
          hue = BitmapDescriptor.hueCyan;
        }

        markers.add(
          Marker(
            markerId: MarkerId('res_$resId'),
            position: LatLng(lat, lng),
            infoWindow: InfoWindow(
              title: "$type ($status)",
              snippet: "Quantity Available: ${r['quantity_available']}",
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(hue),
          ),
        );
      }
    }

    // 3. Add dynamic Backend Incidents (P1 Crisis, P3 Urgent)

    // Dynamic search marker if any
    if (_searchedMarker != null) {
      markers.add(_searchedMarker!);
    }

    // Add real-time active incidents fetched from backend database
    for (final inc in _realIncidents) {
      final isCrisis = inc.severity.contains('P1');
      if (isCrisis && !_showCrisisMarkers) continue;
      if (!isCrisis && !_showConstructionMarkers) continue;

      markers.add(
        Marker(
          markerId: MarkerId('real_${inc.id}'),
          position: inc.position,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            isCrisis ? BitmapDescriptor.hueRed : BitmapDescriptor.hueOrange,
          ),
          infoWindow: InfoWindow(
            title: inc.title,
            snippet: '${inc.severity} (${inc.location})',
          ),
          onTap: () {
            setState(() {
              _selectedIncident = inc;
            });
          },
        ),
      );
    }

    // If there are no real incidents fetched, add the default incident marker so the map isn't blank
    if (_realIncidents.isEmpty) {
      final defInc = _getDefaultIncident();
      markers.add(
        Marker(
          markerId: const MarkerId('default_sinkhole'),
          position: defInc.position,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: defInc.title,
            snippet: '${defInc.severity} (${defInc.location})',
          ),
          onTap: () {
            setState(() {
              _selectedIncident = defInc;
            });
          },
        ),
      );
    }

    // Always ensure the currently selected incident has a marker on the map
    if (_selectedIncident != null) {
      bool activeAdded = false;
      for (var m in markers) {
        if (m.markerId.value.contains(_selectedIncident!.id)) {
          activeAdded = true;
          break;
        }
      }
      if (!activeAdded) {
        final isCrisis = _selectedIncident!.severity.contains('P1') || _selectedIncident!.id == 'KH-201';
        markers.add(
          Marker(
            markerId: MarkerId('active_${_selectedIncident!.id}'),
            position: _selectedIncident!.position,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              isCrisis ? BitmapDescriptor.hueRed : BitmapDescriptor.hueOrange,
            ),
            infoWindow: InfoWindow(
              title: _selectedIncident!.title,
              snippet: '${_selectedIncident!.severity} (${_selectedIncident!.location})',
            ),
          ),
        );
      }
    }

    return markers;
  }

  Set<Polyline> _createPolylines() {
    if (_selectedIncident == null) return {};

    // Enable route simulation if the selected incident is a P1 crisis or the default sinkhole
    final isCrisis = _selectedIncident!.severity.toLowerCase().contains('p1') || 
                     _selectedIncident!.severity.toLowerCase().contains('crisis') ||
                     _selectedIncident!.id == 'KH-201';
    
    if (!isCrisis) return {};
    
    // Dynamic mock route generation relative to the selected incident's position
    final basePos = _selectedIncident!.position;
    
    // Closed road (Red Line) - represents the blocked arterial route (narrowed down slightly to fit the street blocks nicely)
    final closedRoadPoints = [
      LatLng(basePos.latitude - 0.002, basePos.longitude - 0.002),
      basePos, // Center of incident
      LatLng(basePos.latitude + 0.002, basePos.longitude + 0.002),
    ];
    
    // Detour route (Green Dotted Line) - represents the alternate corridor
    final detourPoints = [
      LatLng(basePos.latitude - 0.002, basePos.longitude - 0.002),
      LatLng(basePos.latitude - 0.001, basePos.longitude + 0.003), // Detour curve
      LatLng(basePos.latitude + 0.002, basePos.longitude + 0.002),
    ];

    return {
      Polyline(
        polylineId: const PolylineId('closed_road'),
        points: closedRoadPoints,
        color: kEmergencyRed.withValues(alpha: 0.8),
        width: 6,
      ),
      Polyline(
        polylineId: const PolylineId('reroute_corridor'),
        points: detourPoints,
        color: const Color(0xFF0F5B5C),
        width: 4,
        patterns: [PatternItem.dash(15), PatternItem.gap(12)],
      ),
    };
  }

  // 🎛️ Dynamic beautiful filter panel on clicking the "Filter" icon next to search
  void _showFilterPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setPanelState) {
            final String currentLang = LanguageProvider().language;
            final bool isUrdu = currentLang == 'اردو';

            return Container(
              decoration: const BoxDecoration(
                color: kCardWhite,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    isUrdu ? 'نقشہ فلٹرز' : 'Map Filters',
                    style: GoogleFonts.nunito(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: kTextDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isUrdu ? 'ترجیحات کے مطابق ڈیٹا کو تبدیل کریں' : 'Tailor incident feed display options',
                    style: GoogleFonts.nunito(fontSize: 13, color: kTextLight),
                  ),
                  const SizedBox(height: 24),

                  // ── Map Layer Selector ──
                  Text(
                    isUrdu ? 'نقشہ کی پرتیں' : 'Map Layers',
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: kPrimaryTeal,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: Center(
                            child: Text(
                              isUrdu ? 'نارمل نقشہ' : 'Standard Map',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          selected: _currentMapType == MapType.normal,
                          selectedColor: kPrimaryTeal.withValues(alpha: 0.15),
                          checkmarkColor: kPrimaryTeal,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _currentMapType = MapType.normal;
                              });
                              setPanelState(() {});
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ChoiceChip(
                          label: Center(
                            child: Text(
                              isUrdu ? 'سیٹلائٹ' : 'Satellite Hybrid',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          selected: _currentMapType == MapType.hybrid,
                          selectedColor: kPrimaryTeal.withValues(alpha: 0.15),
                          checkmarkColor: kPrimaryTeal,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _currentMapType = MapType.hybrid;
                              });
                              setPanelState(() {});
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Toggle Filters ──
                  Text(
                    isUrdu ? 'حادثات فلٹر کریں' : 'Incident Visibilities',
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: kPrimaryTeal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: Text(
                      isUrdu ? 'بڑی ہنگامی صورتحال (P1)' : 'P1 Major Emergencies',
                      style: GoogleFonts.nunito(fontSize: 14, color: kTextDark),
                    ),
                    subtitle: Text(
                      isUrdu ? 'سڑک کے گڑھے اور سیلاب' : 'Road collapse, flooding, hazards',
                      style: const TextStyle(fontSize: 11),
                    ),
                    value: _showCrisisMarkers,
                    activeThumbColor: kPrimaryTeal,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) {
                      setState(() {
                        _showCrisisMarkers = val;
                      });
                      setPanelState(() {
                        _showCrisisMarkers = val;
                      });
                    },
                  ),
                  SwitchListTile(
                    title: Text(
                      isUrdu ? 'تعمیراتی کام (P3)' : 'P3 CDA Construction / Utility',
                      style: GoogleFonts.nunito(fontSize: 14, color: kTextDark),
                    ),
                    subtitle: Text(
                      isUrdu ? 'بجلی و روڈ مرمت کی سرگرمیاں' : 'Utility works and active repairing',
                      style: const TextStyle(fontSize: 11),
                    ),
                    value: _showConstructionMarkers,
                    activeThumbColor: kPrimaryTeal,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) {
                      setState(() {
                        _showConstructionMarkers = val;
                      });
                      setPanelState(() {
                        _showConstructionMarkers = val;
                      });
                    },
                  ),
                  const SizedBox(height: 20),

                  // ── Radius Slider ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isUrdu ? 'مانیٹرنگ کا دائرہ کار' : 'Signal Radius Range',
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: kPrimaryTeal,
                        ),
                      ),
                      Text(
                        '${_searchRadius.toStringAsFixed(1)} km',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: kEmergencyRed,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _searchRadius,
                    min: 1.0,
                    max: 25.0,
                    activeColor: kPrimaryTeal,
                    inactiveColor: Colors.grey.shade200,
                    onChanged: (val) {
                      setState(() {
                        _searchRadius = val;
                      });
                      setPanelState(() {
                        _searchRadius = val;
                      });
                    },
                  ),
                  const SizedBox(height: 20),

                  // Close Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryTeal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        isUrdu ? 'ترجیحات لاگو کریں' : 'Apply Settings',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final String currentLang = LanguageProvider().language;
    final bool isUrdu = currentLang == 'اردو';

    // Localized search elements
    String searchHint = 'Search area or route...';
    String getDetourText = 'Get Detour';
    if (isUrdu) {
      searchHint = 'علاقہ یا راستہ تلاش کریں...';
      getDetourText = 'متبادل راستہ';
    } else if (currentLang == 'Roman Urdu') {
      searchHint = 'Ilaqa ya rasta search karein...';
      getDetourText = 'Get Detour';
    }

    final active = _selectedIncident ?? _getDefaultIncident();

    // Dynamic translation setup for incident cards
    String displayTitle = active.title;
    String displayLocation = active.location;
    String displayPlanHeader = active.responsePlanHeader;
    String displaySeverity = active.severity;

    Color severityBg = kEmergencyRed;
    if (active.severity.contains('P3')) {
      severityBg = Colors.orange;
    } else if (active.severity.contains('P5')) {
      severityBg = Colors.green;
    }

    if (isUrdu) {
      displayTitle = active.urduTitle;
      displayLocation = active.urduLocation;
      displayPlanHeader = active.urduResponsePlanHeader;
      if (active.severity.contains('P1')) {
        displaySeverity = 'P1 ہنگامی صورتحال';
      } else if (active.severity.contains('P3')) {
        displaySeverity = 'P3 اہم';
      } else {
        displaySeverity = 'P5 نارمل';
      }
    } else if (currentLang == 'Roman Urdu') {
      displayTitle = active.romanUrduTitle;
    }

    return Scaffold(
      body: Stack(
        children: [          ValueListenableBuilder<bool>(
            valueListenable: ConnectivityService(),
            builder: (context, isOnline, child) {
              if (isOnline && checkGoogleMapsLoaded()) {
                return GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: CameraPosition(
                    target: _islamabadCenter,
                    zoom: 14.5,
                  ),
                  mapType: _currentMapType,
                  markers: _createMarkers(),
                  polylines: _createPolylines(),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: false,
                );
              } else {
                return OfflineVectorMap(
                  incidents: _realIncidents,
                  resources: _realResources,
                  userPosition: _currentPosition != null
                      ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                      : null,
                  selectedIncident: _selectedIncident,
                  onIncidentSelected: (inc) {
                    setState(() {
                      _selectedIncident = inc;
                    });
                  },
                );
              }
            },
          ),


          // ── Offline Overlay Indicator ──
          ValueListenableBuilder<bool>(
            valueListenable: ConnectivityService(),
            builder: (context, isOnline, child) {
              if (isOnline) return const SizedBox.shrink();
              final bool isUrdu = LanguageProvider().language == 'Urdu';
              return Positioned(
                top: MediaQuery.of(context).padding.top + 80, // Safely below top search bar
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_off, color: Colors.orange, size: 14),
                      const SizedBox(width: 8),
                      Text(
                        isUrdu ? "آف لائن موڈ (محفوظ نقشہ فعال)" : "OFFLINE MODE (Cached Map Active)",
                        style: GoogleFonts.nunito(
                          color: Colors.orange,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),


          // ── 2. Top Search Bar and Filter Controls ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _isLoadingSearch
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: kPrimaryTeal,
                                ),
                              )
                            : GestureDetector(
                                onTap: _performSearch,
                                child: const Icon(Icons.search, color: Colors.grey, size: 22),
                              ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onSubmitted: (_) => _performSearch(),
                            textInputAction: TextInputAction.search,
                            decoration: InputDecoration(
                              hintText: searchHint,
                              hintStyle: GoogleFonts.nunito(
                                color: Colors.grey.shade500,
                                fontSize: 15,
                              ),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  height: 52,
                  width: 52,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _showFilterPanel, // Open the premium filter settings sheet
                      child: const Icon(
                        Icons.tune,
                        color: Color(0xFF0F5B5C),
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── 3. Bottom Premium Incident Card ──
          if (_selectedIncident != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: const BoxDecoration(
                  color: kCardWhite,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 15,
                      spreadRadius: 2,
                      offset: Offset(0, -3),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Pull Handle Accent + Close Button Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox(width: 24), // Spacer to balance close button
                        Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        IconButton(
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                          onPressed: () {
                            setState(() {
                              _selectedIncident = null;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Header Badge + Location + Distance
                    Row(
                      children: [
                        // Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: severityBg,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            displaySeverity,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Location Text
                        Expanded(
                          child: Text(
                            displayLocation,
                            style: GoogleFonts.nunito(
                              color: kTextLight,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Distance Info
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              color: kEmergencyRed,
                              size: 15,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              active.id == 'KH-201' ? '1.2km' : '0.0km',
                              style: GoogleFonts.nunito(
                                color: kEmergencyRed,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Incident Main Title
                    Text(
                      displayTitle,
                      style: GoogleFonts.nunito(
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        color: kTextDark,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Automated Response Plan Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Stack(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Plan Title
                              Text(
                                displayPlanHeader,
                                style: GoogleFonts.nunito(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: kPrimaryTeal,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Plan Step 1
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 22,
                                    height: 22,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: kPrimaryTeal,
                                    ),
                                    child: const Center(
                                      child: Text(
                                        '1',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isUrdu
                                              ? active.steps[0].urduTitle
                                              : active.steps[0].title,
                                          style: GoogleFonts.nunito(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13.5,
                                            color: kTextDark,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          isUrdu
                                              ? active.steps[0].urduSubtitle
                                              : active.steps[0].subtitle,
                                          style: GoogleFonts.nunito(
                                            fontSize: 11.5,
                                            color: kTextLight,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Plan Step 2
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.grey.shade300,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '2',
                                        style: TextStyle(
                                          color: Colors.grey.shade700,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isUrdu
                                              ? active.steps[1].urduTitle
                                              : active.steps[1].title,
                                          style: GoogleFonts.nunito(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13.5,
                                            color: kTextDark,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          isUrdu
                                              ? active.steps[1].urduSubtitle
                                              : active.steps[1].subtitle,
                                          style: GoogleFonts.nunito(
                                            fontSize: 11.5,
                                            color: kTextLight,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          // Sleek Circular Watermark Pattern on the right matching UI
                          Positioned(
                            right: -10,
                            top: -10,
                            child: Opacity(
                              opacity: 0.04,
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: kPrimaryTeal,
                                    width: 6,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Bottom Action Buttons Row
                    Row(
                      children: [
                        // "Get Detour" Button
                        Expanded(
                          child: Container(
                            height: 52,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: kPrimaryTeal.withValues(alpha: 0.15),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kPrimaryTeal,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      isUrdu
                                          ? 'متبادل راستے کا حساب لگایا جا رہا ہے...'
                                          : 'Calculating detour routes...',
                                    ),
                                    backgroundColor: kPrimaryTeal,
                                  ),
                                );
                              },
                              icon: const Icon(
                                Icons.directions,
                                color: Colors.white,
                                size: 20,
                              ),
                              label: Text(
                                getDetourText,
                                style: GoogleFonts.nunito(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Share Button
                        Container(
                          height: 52,
                          width: 52,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      isUrdu
                                          ? 'الرٹ رپورٹ شیئر کی جا رہی ہے...'
                                          : 'Sharing incident alert report...',
                                    ),
                                    backgroundColor: kPrimaryTeal,
                                  ),
                                );
                              },
                              child: const Icon(
                                Icons.share_outlined,
                                color: kTextDark,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
  }
}

class OfflineNode {
  final String name;
  final String urduName;
  final double x;
  final double y;
  final double lat;
  final double lng;

  OfflineNode({
    required this.name,
    required this.urduName,
    required this.x,
    required this.y,
    required this.lat,
    required this.lng,
  });
}

class OfflineVectorMap extends StatefulWidget {
  final List<MapIncident> incidents;
  final List<dynamic> resources;
  final LatLng? userPosition;
  final MapIncident? selectedIncident;
  final ValueChanged<MapIncident> onIncidentSelected;

  const OfflineVectorMap({
    super.key,
    required this.incidents,
    required this.resources,
    required this.userPosition,
    required this.selectedIncident,
    required this.onIncidentSelected,
  });

  @override
  State<OfflineVectorMap> createState() => _OfflineVectorMapState();
}

class _OfflineVectorMapState extends State<OfflineVectorMap> {
  final List<OfflineNode> _nodes = [
    OfflineNode(name: "Sector E-11", urduName: "سیکٹر E-11", x: 120, y: 90, lat: 33.7001, lng: 72.9812),
    OfflineNode(name: "Sector G-11", urduName: "سیکٹر G-11", x: 120, y: 190, lat: 33.6766, lng: 73.0132),
    OfflineNode(name: "Sector F-6", urduName: "سیکٹر F-6", x: 550, y: 90, lat: 33.7299, lng: 73.0746),
    OfflineNode(name: "Blue Area", urduName: "بلیو ایریا", x: 350, y: 140, lat: 33.7182, lng: 73.0605),
    OfflineNode(name: "I-8 Interchange", urduName: "آئی-8 انٹرچینج", x: 350, y: 410, lat: 33.6698, lng: 73.0741),
    OfflineNode(name: "Faizabad", urduName: "فیض آباد", x: 550, y: 490, lat: 33.6375, lng: 73.0784),
    OfflineNode(name: "Shamsabad", urduName: "شمس آباد", x: 550, y: 590, lat: 33.6338, lng: 73.0747),
    OfflineNode(name: "Saddar Rawalpindi", urduName: "صدر راولپنڈی", x: 550, y: 710, lat: 33.5984, lng: 73.0544),
    OfflineNode(name: "Nullah Lai Area", urduName: "نالہ لئی کا علاقہ", x: 300, y: 610, lat: 33.6105, lng: 73.0783),
  ];

  @override
  Widget build(BuildContext context) {
    final String currentLang = LanguageProvider().language;
    final bool isUrdu = currentLang == 'اردو';

    return Container(
      color: const Color(0xFF0F172A), // Premium dark slate background
      child: InteractiveViewer(
        maxScale: 3.5,
        minScale: 0.5,
        boundaryMargin: const EdgeInsets.all(100),
        child: Center(
          child: Container(
            width: 700,
            height: 800,
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              border: Border.all(color: Colors.white10),
            ),
            child: Stack(
              children: [
                // 1. Blueprint Grid Background
                ...List.generate(15, (i) {
                  return Positioned(
                    left: i * 50.0,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 0.5,
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  );
                }),
                ...List.generate(17, (i) {
                  return Positioned(
                    top: i * 50.0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 0.5,
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  );
                }),

                // 2. Vector Roads & Corridors
                // Jinnah Avenue (F-6 to E-11 via Blue Area)
                _buildRoadLine(120, 90, 350, 140, Colors.teal.shade700),
                _buildRoadLine(350, 140, 550, 90, Colors.teal.shade700),
                _buildRoadLine(120, 90, 120, 190, Colors.teal.shade700),
                
                // Expressway (F-6 down to I-8 and Faizabad)
                _buildRoadLine(550, 90, 350, 410, Colors.teal.shade700),
                _buildRoadLine(350, 410, 550, 490, Colors.teal.shade700),
                
                // Murree Road (Faizabad to Saddar)
                _buildRoadLine(550, 490, 550, 590, Colors.teal.shade700),
                _buildRoadLine(550, 590, 550, 710, Colors.teal.shade700),

                // Nullah Lai Stream
                _buildRoadLine(120, 190, 300, 610, Colors.blue.withValues(alpha: 0.3), isStream: true),
                _buildRoadLine(300, 610, 550, 710, Colors.blue.withValues(alpha: 0.3), isStream: true),

                // Dynamic Detour highlight for F-6 / G-11 / Faizabad / Nullah Lai
                _buildDetourHighlights(),

                // 3. Render Offline Sector Nodes
                ..._nodes.map((node) {
                  final isSelected = widget.selectedIncident != null &&
                      (widget.selectedIncident!.location.toLowerCase().contains(node.name.toLowerCase()) ||
                       widget.selectedIncident!.title.toLowerCase().contains(node.name.toLowerCase()) ||
                       node.name.toLowerCase().contains(widget.selectedIncident!.location.toLowerCase()));

                  return Positioned(
                    left: node.x - 45,
                    top: node.y - 45,
                    child: GestureDetector(
                      onTap: () {
                        // Create a mock incident for this sector node on-tap
                        final mockInc = MapIncident(
                          id: 'OFF-INC-${node.name.split(" ").last}',
                          title: '${node.name} Alert',
                          urduTitle: '${node.urduName} الرٹ',
                          romanUrduTitle: '${node.name} Alert',
                          position: LatLng(node.lat, node.lng),
                          severity: 'P1 CRISIS',
                          location: node.name,
                          urduLocation: node.urduName,
                          responsePlanHeader: 'Offline Emergency Plan',
                          urduResponsePlanHeader: 'آف لائن ہنگامی منصوبہ',
                          steps: [
                            ResponseStep(
                              title: 'Offline warning broadcasted locally.',
                              urduTitle: 'آف لائن وارننگ مقامی طور پر نشر کی گئی۔',
                              subtitle: 'Check offline chatbot for guidelines.',
                              urduSubtitle: 'رہنما خطوط کے لیے آف لائن چیٹ بوٹ چیک کریں۔',
                            ),
                            ResponseStep(
                              title: 'Local rescue points activated.',
                              urduTitle: 'مقامی ریسکیو پوائنٹس فعال ہو گئے۔',
                              subtitle: 'Rescue 1122 standby.',
                              urduSubtitle: 'ریسکیو 1122 اسٹینڈ بائی پر ہے۔',
                            ),
                          ],
                        );
                        widget.onIncidentSelected(mockInc);
                      },
                      child: Container(
                        width: 90,
                        height: 90,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                if (isSelected)
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.red.withValues(alpha: 0.3),
                                    ),
                                  ),
                                Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected ? Colors.red : const Color(0xFF0F5B5C),
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black45,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isUrdu ? node.urduName : node.name,
                                style: GoogleFonts.nunito(
                                  color: isSelected ? Colors.redAccent : Colors.white70,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),

                // 4. Render user location dot (if available)
                if (widget.userPosition != null)
                  Positioned(
                    left: 350 - 10,
                    top: 250 - 10,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.blue.withValues(alpha: 0.3),
                      ),
                      child: Center(
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ),
                  ),

                // 5. Offline Indicators Overlay
                Positioned(
                  top: 20,
                  left: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.wifi_off, color: Colors.orange, size: 14),
                        const SizedBox(width: 8),
                        Text(
                          isUrdu ? "آف لائن ویکٹر نقشہ" : "OFFLINE VECTOR MAP",
                          style: GoogleFonts.nunito(
                            color: Colors.orange,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoadLine(double x1, double y1, double x2, double y2, Color color, {bool isStream = false}) {
    return Positioned.fill(
      child: CustomPaint(
        painter: LinePainter(x1: x1, y1: y1, x2: x2, y2: y2, color: color, isStream: isStream),
      ),
    );
  }

  Widget _buildDetourHighlights() {
    final active = widget.selectedIncident;
    if (active == null) return const SizedBox.shrink();

    // Map selected location name to detour paths
    final loc = active.location.toLowerCase();
    
    double startX = 350, startY = 410; // I-8
    double endX = 550, endY = 490; // Faizabad
    
    if (loc.contains("g-11") || loc.contains("e-11")) {
      startX = 120; startY = 90;
      endX = 350; endY = 140;
    } else if (loc.contains("f-6") || loc.contains("blue area")) {
      startX = 350; startY = 140;
      endX = 550; endY = 90;
    } else if (loc.contains("saddar") || loc.contains("shamsabad") || loc.contains("lai")) {
      startX = 550; startY = 490;
      endX = 550; endY = 710;
    }

    return Positioned.fill(
      child: CustomPaint(
        painter: DetourPainter(startX: startX, startY: startY, endX: endX, endY: endY),
      ),
    );
  }
}

class LinePainter extends CustomPainter {
  final double x1;
  final double y1;
  final double x2;
  final double y2;
  final Color color;
  final bool isStream;

  LinePainter({required this.x1, required this.y1, required this.x2, required this.y2, required this.color, required this.isStream});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = isStream ? 8.0 : 4.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    if (isStream) {
      // Draw wavy line for water streams
      final path = Path();
      path.moveTo(x1, y1);
      double midX = (x1 + x2) / 2;
      double midY = (y1 + y2) / 2;
      path.quadraticBezierTo(midX - 20, midY - 20, x2, y2);
      canvas.drawPath(path, paint);
    } else {
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class DetourPainter extends CustomPainter {
  final double startX;
  final double startY;
  final double endX;
  final double endY;

  DetourPainter({required this.startX, required this.startY, required this.endX, required this.endY});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Red Blocked Road
    final redPaint = Paint()
      ..color = Colors.red.withValues(alpha: 0.8)
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(startX, startY), Offset(endX, endY), redPaint);

    // 2. Green Dotted Detour
    final greenPaint = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Draw arc detour
    final path = Path();
    path.moveTo(startX, startY);
    
    // Control point for curve
    double ctrlX = (startX + endX) / 2 - 80;
    double ctrlY = (startY + endY) / 2 - 80;
    path.quadraticBezierTo(ctrlX, ctrlY, endX, endY);

    // Render as dashed/dotted path manually
    final pMetrics = path.computeMetrics();
    for (var metric in pMetrics) {
      double length = metric.length;
      double step = 10.0;
      for (double i = 0.0; i < length; i += step * 2) {
        final pathSegment = metric.extractPath(i, i + step);
        canvas.drawPath(pathSegment, greenPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

