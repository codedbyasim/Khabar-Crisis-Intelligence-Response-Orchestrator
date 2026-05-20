import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:khabar/theme/app_colors.dart';
import 'package:khabar/theme/language_provider.dart';
import 'package:khabar/api_config.dart';
import 'package:geolocator/geolocator.dart';

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

  late MapIncident _activeIncident;
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
    // Default featured incident corresponding exactly to "Major Road Sinkhole" in Jinnah Avenue, Islamabad
    _activeIncident = _getDefaultIncident();
    _fetchRealIncidents();
    _fetchRealResources();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return; // Service not enabled

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    
    if (permission == LocationPermission.deniedForever) return;

    final position = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
    if (mounted) {
      setState(() {
        _currentPosition = position;
      });
      // Optionally center map on user's live location
      // mapController.animateCamera(CameraUpdate.newLatLng(LatLng(position.latitude, position.longitude)));
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
          if (_realIncidents.isNotEmpty) {
            _activeIncident = _realIncidents.first;
          }
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

    // 1. First check our local high-speed dictionary of Pakistan cities for instant offline results
    if (normalized == 'islamabad') {
      targetLatLng = const LatLng(33.6844, 73.0479);
      locationName = 'Islamabad Capital City';
      urduLocationName = 'اسلام آباد وفاقی دارالحکومت';
    } else if (normalized == 'karachi') {
      targetLatLng = const LatLng(24.8607, 67.0011);
      locationName = 'Karachi, Sindh';
      urduLocationName = 'کراچی، سندھ';
    } else if (normalized == 'lahore') {
      targetLatLng = const LatLng(31.5204, 74.3587);
      locationName = 'Lahore, Punjab';
      urduLocationName = 'لاہور، پنجاب';
    } else if (normalized == 'rawalpindi') {
      targetLatLng = const LatLng(33.5651, 73.0169);
      locationName = 'Rawalpindi, Punjab';
      urduLocationName = 'راولپنڈی، پنجاب';
    } else if (normalized == 'peshawar') {
      targetLatLng = const LatLng(34.0151, 71.5249);
      locationName = 'Peshawar, KPK';
      urduLocationName = 'پشاور، خیبر پختونخوا';
    } else if (normalized == 'blue area' || normalized == 'jinnah avenue') {
      targetLatLng = const LatLng(33.7220, 73.0580);
      locationName = 'Jinnah Avenue, Blue Area';
      urduLocationName = 'جناح ایونیو، بلیو ایریا';
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
      // Smoothly animate Google Map camera to the searched coordinate
      mapController.animateCamera(
        CameraUpdate.newLatLngZoom(targetLatLng, 14.5),
      );

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
        _activeIncident = MapIncident(
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
            content: const Text('Location not found. Please try searching cities like "Karachi", "Lahore", or "Blue Area".'),
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
              _activeIncident = inc;
            });
          },
        ),
      );
    }

    return markers;
  }

  Set<Polyline> _createPolylines() {
    // Green/Teal dotted rerouting line matching the reference UI
    final points = [
      const LatLng(33.7380, 73.0350), // Saidpur/Khyber border side
      const LatLng(33.7220, 73.0580), // Jinnah Ave incident
      const LatLng(33.7120, 73.0680), // Blue Area side
    ];

    return {
      Polyline(
        polylineId: const PolylineId('reroute_corridor'),
        points: points,
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

    // Dynamic translation setup for incident cards
    String displayTitle = _activeIncident.title;
    String displayLocation = _activeIncident.location;
    String displayPlanHeader = _activeIncident.responsePlanHeader;
    String displaySeverity = _activeIncident.severity;

    Color severityBg = kEmergencyRed;
    if (_activeIncident.severity.contains('P3')) {
      severityBg = Colors.orange;
    } else if (_activeIncident.severity.contains('P5')) {
      severityBg = Colors.green;
    }

    if (isUrdu) {
      displayTitle = _activeIncident.urduTitle;
      displayLocation = _activeIncident.urduLocation;
      displayPlanHeader = _activeIncident.urduResponsePlanHeader;
      if (_activeIncident.severity.contains('P1')) {
        displaySeverity = 'P1 ہنگامی صورتحال';
      } else if (_activeIncident.severity.contains('P3')) {
        displaySeverity = 'P3 اہم';
      } else {
        displaySeverity = 'P5 نارمل';
      }
    } else if (currentLang == 'Roman Urdu') {
      displayTitle = _activeIncident.romanUrduTitle;
    }

    return Scaffold(
      body: Stack(
        children: [
          // ── 1. Google Maps Base Layer ──
          GoogleMap(
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
                  // Pull Handle Accent
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
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
                            _activeIncident.id == 'KH-201' ? '1.2km' : '0.0km',
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
                                            ? _activeIncident.steps[0].urduTitle
                                            : _activeIncident.steps[0].title,
                                        style: GoogleFonts.nunito(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13.5,
                                          color: kTextDark,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        isUrdu
                                            ? _activeIncident.steps[0].urduSubtitle
                                            : _activeIncident.steps[0].subtitle,
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
                                            ? _activeIncident.steps[1].urduTitle
                                            : _activeIncident.steps[1].title,
                                        style: GoogleFonts.nunito(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13.5,
                                          color: kTextDark,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        isUrdu
                                            ? _activeIncident.steps[1].urduSubtitle
                                            : _activeIncident.steps[1].subtitle,
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
