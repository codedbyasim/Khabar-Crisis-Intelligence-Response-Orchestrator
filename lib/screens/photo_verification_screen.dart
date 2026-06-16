import 'dart:io';
import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:khabar/theme/app_colors.dart';
import 'package:khabar/theme/language_provider.dart';
import 'package:khabar/screens/incident_tracker_screen.dart';
import 'package:khabar/api_config.dart';
import 'package:khabar/utils/location_helper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:khabar/utils/connectivity_service.dart';
import 'package:khabar/utils/web_helper.dart';


class PhotoVerificationScreen extends StatefulWidget {
  const PhotoVerificationScreen({super.key});

  @override
  State<PhotoVerificationScreen> createState() => _PhotoVerificationScreenState();
}

class _PhotoVerificationScreenState extends State<PhotoVerificationScreen> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  XFile? _capturedImage;
  bool _isCameraInitialized = false;
  bool _isSubmitting = false;
  double _lat = 33.6844;
  double _lng = 73.0479;
  final TextEditingController _descriptionController = TextEditingController();

  GoogleMapController? _mapController;
  late LatLng _markerPosition;
  bool _isFetchingLocation = false;
  String? _locationStatus;

  @override
  void initState() {
    super.initState();
    _initCamera();
    
    final String region = LanguageProvider().region;
    final bool isRawalpindi = region.toLowerCase().contains('rawalpindi');
    _markerPosition = LatLng(
      isRawalpindi ? 33.5651 : 33.6844,
      isRawalpindi ? 73.0169 : 73.0479,
    );

    _fetchDeviceLocation();
  }

  Future<void> _fetchDeviceLocation() async {
    try {
      final result = await LocationHelper.fetchLocation();
      if (mounted) {
        setState(() {
          _lat = result.position.latitude;
          _lng = result.position.longitude;
          _markerPosition = result.position;
          _locationStatus = result.source != 'default' ? 'ok' : 'err';
        });
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(result.position, 16),
        );
        debugPrint('[GPS] Photo screen location resolved to ($_lat, $_lng) via source: ${result.source}');
      }
    } catch (e) {
      debugPrint("Photo screen GPS error: $e");
    }
  }

  Future<void> _fetchGPS({bool showErrors = true}) async {
    if (_isFetchingLocation) return;
    if (mounted) setState(() => _isFetchingLocation = true);

    try {
      final result = await LocationHelper.fetchLocation();
      if (mounted) {
        setState(() {
          _lat = result.position.latitude;
          _lng = result.position.longitude;
          _markerPosition = result.position;
          _locationStatus = result.source != 'default' ? 'ok' : 'err';
          _isFetchingLocation = false;
        });
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(result.position, 16),
        );

        if (showErrors) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.source == 'ip' 
                ? 'Mock coordinates via IP: (${result.position.latitude.toStringAsFixed(4)}, ${result.position.longitude.toStringAsFixed(4)})'
                : 'Current GPS location set successfully.'),
              backgroundColor: kPrimaryTeal,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) setState(() { _locationStatus = 'err'; _isFetchingLocation = false; });
    }
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        _cameraController = CameraController(_cameras![0], ResolutionPreset.high);
        await _cameraController!.initialize();
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
        }
      }
    } catch (e) {
      debugPrint("Error initializing camera: $e");
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _descriptionController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    if (_cameraController!.value.isTakingPicture) {
      return;
    }
    try {
      XFile picture = await _cameraController!.takePicture();
      setState(() {
        _capturedImage = picture;
      });
    } catch (e) {
      debugPrint("Error taking picture: $e");
    }
  }

  Future<void> _uploadFromGallery() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() {
          _capturedImage = picked;
        });
      }
    } catch (e) {
      debugPrint("Gallery picker error: $e");
    }
  }

  Future<void> _analyzeAndSubmit() async {
    if (_capturedImage == null) return;
    setState(() => _isSubmitting = true);
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/report/image');
      final request = http.MultipartRequest('POST', uri);
      final imageBytes = await File(_capturedImage!.path).readAsBytes();
      request.files.add(http.MultipartFile.fromBytes(
        'image', imageBytes,
        filename: 'crisis_photo.jpg',
      ));
      final String region = LanguageProvider().region;
      request.fields['lat'] = _markerPosition.latitude.toString();
      request.fields['lng'] = _markerPosition.longitude.toString();
      request.fields['description'] = _descriptionController.text.isNotEmpty 
          ? _descriptionController.text 
          : 'Photo report from KHABAR app ($region)';

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

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
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Photo Verification', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _capturedImage == null
          ? Column(
              children: [
                Expanded(child: _buildLiveCamera()),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    color: kBackgroundLight,
                    child: _buildCaptureControls(),
                  ),
                ),
              ],
            )
          : Container(
              color: kBackgroundLight,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Captured Image Preview Card
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        children: [
                          Image.file(
                            File(_capturedImage!.path),
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                          Positioned(
                            bottom: 12,
                            right: 12,
                            child: ElevatedButton.icon(
                              onPressed: _isSubmitting ? null : () {
                                setState(() {
                                  _capturedImage = null;
                                });
                              },
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retake'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black54,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Description
                    Text(
                      'Incident Description',
                      style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.bold, color: kTextDark),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Describe the damage or incident details... / تفصیلات درج کریں...',
                        hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
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
                        filled: true,
                        fillColor: kCardWhite,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Location Picker Map
                    Text(
                      'Specify Location',
                      style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.bold, color: kTextDark),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 240,
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
                                if (isOnline && checkGoogleMapsLoaded()) {
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
                                          style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.bold, color: kTextDark),
                                        ),
                                        const SizedBox(height: 6),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 24),
                                          child: Text(
                                            'Google Maps is unavailable offline. Using coordinates: (${_markerPosition.latitude.toStringAsFixed(4)}, ${_markerPosition.longitude.toStringAsFixed(4)})',
                                            style: GoogleFonts.nunito(fontSize: 12, color: kTextLight),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                              },
                            ),
                            Positioned(
                              top: 10,
                              right: 10,
                              child: GestureDetector(
                                onTap: () => _fetchGPS(showErrors: true),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                                          child: CircularProgressIndicator(strokeWidth: 2, color: kPrimaryTeal),
                                        )
                                      else
                                        Icon(
                                          _locationStatus == 'ok' ? Icons.my_location : Icons.location_searching,
                                          size: 14,
                                          color: _locationStatus == 'ok' ? kPrimaryTeal : Colors.grey.shade600,
                                        ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _isFetchingLocation ? 'Locating...' : _locationStatus == 'ok' ? 'Location Set ✓' : 'Use My Location',
                                        style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.bold, color: _locationStatus == 'ok' ? kPrimaryTeal : Colors.grey.shade700),
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
                    Text(
                      'Tap/drag the map marker or use GPS to set coordinate location',
                      style: GoogleFonts.nunito(fontSize: 11, color: kTextLight),
                    ),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: _capturedImage == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _analyzeAndSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryTeal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Send to Gemini Pipeline →',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ),
    );
  }

  Widget _buildLiveCamera() {
    if (!_isCameraInitialized || _cameraController == null) {
      return const Center(child: CircularProgressIndicator(color: kPrimaryTeal));
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(_cameraController!),
        CustomPaint(
          painter: GridOverlayPainter(),
        ),
      ],
    );
  }

  Widget _buildCaptureControls() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Align subject within grid or upload photo / گیلری سے اپ لوڈ کریں',
          style: GoogleFonts.nunito(fontSize: 15, color: kTextLight),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Gallery button
            InkWell(
              onTap: _uploadFromGallery,
              borderRadius: BorderRadius.circular(28),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: const Icon(Icons.photo_library_outlined, color: kPrimaryTeal, size: 26),
              ),
            ),
            const SizedBox(width: 36),
            
            // Camera capture button
            InkWell(
              onTap: _takePicture,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: kPrimaryTeal, width: 4),
                ),
                child: Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: kPrimaryTeal,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 32),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 36),
            
            // Empty placeholder for symmetry
            const SizedBox(
              width: 56,
              height: 56,
            ),
          ],
        ),
      ],
    );
  }
}

class GridOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..strokeWidth = 1.0;

    // Draw horizontal lines (rule of thirds)
    canvas.drawLine(Offset(0, size.height / 3), Offset(size.width, size.height / 3), paint);
    canvas.drawLine(Offset(0, size.height * 2 / 3), Offset(size.width, size.height * 2 / 3), paint);

    // Draw vertical lines (rule of thirds)
    canvas.drawLine(Offset(size.width / 3, 0), Offset(size.width / 3, size.height), paint);
    canvas.drawLine(Offset(size.width * 2 / 3, 0), Offset(size.width * 2 / 3, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
