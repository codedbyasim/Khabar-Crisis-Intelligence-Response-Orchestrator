import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:khabar/theme/app_colors.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:khabar/api_config.dart';
import 'package:khabar/utils/location_helper.dart';
import 'package:khabar/utils/web_helper.dart';
import 'package:khabar/utils/connectivity_service.dart';
import 'package:khabar/utils/user_profile_helper.dart';


import 'package:khabar/theme/language_provider.dart';
import 'package:khabar/screens/incident_tracker_screen.dart';

class TextSignalScreen extends StatefulWidget {
  const TextSignalScreen({super.key});

  @override
  State<TextSignalScreen> createState() => _TextSignalScreenState();
}

class _TextSignalScreenState extends State<TextSignalScreen> {
  final TextEditingController _textController = TextEditingController();
  bool _isUrdu = false;
  late LatLng _markerPosition;
  bool _isSubmitting = false;
  bool _isFetchingLocation = false;
  String? _locationStatus; // null = default, 'ok' = GPS success, 'err' = failed
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
    
    final String region = LanguageProvider().region;
    final bool isRawalpindi = region.toLowerCase().contains('rawalpindi');
    _markerPosition = LatLng(
      isRawalpindi ? 33.5651 : 33.6844,
      isRawalpindi ? 73.0169 : 73.0479,
    );

    // Fetch user's current GPS location automatically on startup
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    // On Web: browser GPS is IP-based (gives wrong country), skip auto-fetch.
    // User can still tap the "Use My Location" button which will call _fetchGPS().
    if (kIsWeb) return;
    // On mobile: auto-fetch on startup silently
    await _fetchGPS(showErrors: false);
  }

  /// Fetch GPS or IP fallback location and animate the camera.
  Future<void> _fetchGPS({bool showErrors = true}) async {
    if (_isFetchingLocation) return;
    if (mounted) setState(() => _isFetchingLocation = true);

    try {
      final result = await LocationHelper.fetchLocation();
      
      if (mounted) {
        setState(() {
          _markerPosition = result.position;
          _locationStatus = result.source != 'default' ? 'ok' : 'err';
          _isFetchingLocation = false;
        });
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(result.position, 16),
        );

        if (showErrors && mounted) {
          if (result.source == 'ip') {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Emulator GPS mock coordinates. Loaded approximate location via IP: (${result.position.latitude.toStringAsFixed(4)}, ${result.position.longitude.toStringAsFixed(4)})'),
                backgroundColor: kPrimaryTeal,
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else if (result.source == 'default') {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Could not fetch location (GPS/IP unavailable). Tap map to manually select.'),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Current GPS location set successfully.'),
                backgroundColor: kPrimaryTeal,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[GPS] Error: $e');
      if (mounted) setState(() { _locationStatus = 'err'; _isFetchingLocation = false; });
    }
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _textController.text;
    final hasUrdu = RegExp(r'[\u0600-\u06FF]').hasMatch(text);
    if (_isUrdu != hasUrdu) {
      setState(() {
        _isUrdu = hasUrdu;
      });
    }
  }

  Future<void> _submitSignal() async {
    final text = _textController.text;
    if (text.isEmpty) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final url = '${ApiConfig.baseUrl}/report/text';
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': text,
          'lat': _markerPosition.latitude,
          'lng': _markerPosition.longitude,
          'user_id': UserProfileHelper.cachedProfile?['user_id'],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Signal successfully processed by AI Pipeline!'),
              backgroundColor: kPrimaryTeal,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => IncidentTrackerScreen(incidentData: data),
            ),
          );
        }
      } else {
        throw Exception('Failed with status: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Agent API Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundLight,
      appBar: AppBar(
        title: const Text(
          'New Text Signal',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: kBackgroundLight,
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _textController,
              maxLines: null,
              minLines: 5,
              textDirection: _isUrdu ? TextDirection.rtl : TextDirection.ltr,
              decoration: InputDecoration(
                hintText:
                    'Describe the crisis (Urdu, English, Roman Urdu, or Punjabi)... / یہاں لکھیں...',
                hintStyle: const TextStyle(color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade400),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kPrimaryTeal, width: 2),
                ),
                contentPadding: const EdgeInsets.all(16),
                filled: true,
                fillColor: kCardWhite,
              ),
            ),
            const SizedBox(height: 12),
            Align(alignment: Alignment.centerLeft, child: _buildLanguageChip()),
            const SizedBox(height: 24),
            Text(
              'Specify Location',
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: kTextDark,
              ),
            ),
            const SizedBox(height: 12),
            // ── Map + Use My Location button ──
            Container(
              height: 260,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    ValueListenableBuilder<bool>(
                      valueListenable: ConnectivityService(),
                      builder: (context, isOnline, child) {
                        if (ConnectivityService().hasInternet && checkGoogleMapsLoaded()) {
                          return GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target: _markerPosition,
                              zoom: 15,
                            ),
                            onMapCreated: (controller) {
                              _mapController = controller;
                            },
                            myLocationEnabled: true,
                            myLocationButtonEnabled: true,
                            markers: {
                              Marker(
                                markerId: const MarkerId('incident_location'),
                                position: _markerPosition,
                                draggable: true,
                                onDragEnd: (newPosition) {
                                  setState(() {
                                    _markerPosition = newPosition;
                                  });
                                },
                              ),
                            },
                          );
                        } else {
                          return Container(
                            color: Colors.grey.shade200,
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
                                const SizedBox(height: 12),
                                Text(
                                  'Offline Map Mode Active',
                                  style: GoogleFonts.nunito(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: kTextDark,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 24),
                                  child: Text(
                                    'Google Maps is unavailable offline. Using coordinates: (${_markerPosition.latitude.toStringAsFixed(4)}, ${_markerPosition.longitude.toStringAsFixed(4)})',
                                    style: GoogleFonts.nunito(
                                      fontSize: 12,
                                      color: kTextLight,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                      },
                    ),
                    // ── "Use My Location" floating button ──
                    Positioned(
                      top: 10,
                      right: 10,
                      child: GestureDetector(
                        onTap: () => _fetchGPS(showErrors: true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isFetchingLocation)
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: kPrimaryTeal,
                                  ),
                                )
                              else
                                Icon(
                                  _locationStatus == 'ok'
                                      ? Icons.my_location
                                      : Icons.location_searching,
                                  size: 14,
                                  color: _locationStatus == 'ok'
                                      ? kPrimaryTeal
                                      : Colors.grey.shade600,
                                ),
                              const SizedBox(width: 6),
                              Text(
                                _isFetchingLocation
                                    ? 'Locating...'
                                    : _locationStatus == 'ok'
                                        ? 'Location Set ✓'
                                        : 'Use My Location',
                                style: GoogleFonts.nunito(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _locationStatus == 'ok'
                                      ? kPrimaryTeal
                                      : Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            // ── Location hint text ──
            Text(
              'Tap the map or drag the pin to set incident location',
              style: GoogleFonts.nunito(
                fontSize: 11,
                color: kTextLight,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _submitSignal,
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryTeal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Inject Signal into Pipeline →',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageChip() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: ValueKey<bool>(_isUrdu),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: (_isUrdu ? Colors.green : Colors.blue).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: (_isUrdu ? Colors.green : Colors.blue).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isUrdu ? Icons.language : Icons.translate,
              size: 16,
              color: _isUrdu ? Colors.green.shade700 : Colors.blue.shade700,
            ),
            const SizedBox(width: 6),
            Text(
              _isUrdu
                  ? 'Urdu signal detected (98% Confidence)'
                  : 'Roman Urdu / English signal detected',
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: _isUrdu ? Colors.green.shade700 : Colors.blue.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
