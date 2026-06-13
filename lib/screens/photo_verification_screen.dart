import 'dart:io';
import 'dart:ui';
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
  Map<String, dynamic>? _visionResult;
  double _lat = 33.6844;
  double _lng = 73.0479;
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initCamera();
    _fetchDeviceLocation();
  }

  Future<void> _fetchDeviceLocation() async {
    try {
      final result = await LocationHelper.fetchLocation();
      if (mounted) {
        setState(() {
          _lat = result.position.latitude;
          _lng = result.position.longitude;
        });
        debugPrint('[GPS] Photo screen location resolved to ($_lat, $_lng) via source: ${result.source}');
      }
    } catch (e) {
      debugPrint("Photo screen GPS error: $e");
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
      request.fields['lat'] = _lat.toString();
      request.fields['lng'] = _lng.toString();
      request.fields['description'] = _descriptionController.text.isNotEmpty 
          ? _descriptionController.text 
          : 'Photo report from KHABAR app ($region)';

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _visionResult = data['vision_analysis'] as Map<String, dynamic>?;
            _isSubmitting = false;
          });
          // Wait 1.5s so user can see result, then navigate
          await Future.delayed(const Duration(milliseconds: 1500));
          if (mounted) {
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => IncidentTrackerScreen(incidentData: data),
                transitionsBuilder: (context, animation, secondaryAnimation, child) => FadeTransition(opacity: animation, child: child),
              ),
            );
          }
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
      body: Column(
        children: [
          // Top Half: Live Camera Preview
          Expanded(
            child: _buildLiveCamera(),
          ),
          
          // Bottom Half: Capture Controls OR Captured Image + Overlay
          Expanded(
            child: Container(
              width: double.infinity,
              color: kBackgroundLight,
              child: _capturedImage == null
                  ? _buildCaptureControls()
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(
                          File(_capturedImage!.path),
                          fit: BoxFit.cover,
                        ),
                        // Glassmorphism Overlay
                        Positioned.fill(
                          child: _buildAnalysisOverlay(),
                        ),
                      ],
                    ),
            ),
          ),
        ],
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

  Widget _buildAnalysisOverlay() {
    final crisisType = _visionResult?['crisis_type'] ?? 'Analyzing...';
    final severity = _visionResult?['severity'] ?? '—';
    final priority = _visionResult?['priority'] ?? '—';
    final confidence = _visionResult != null
        ? '${((_visionResult!['confidence'] ?? 0) * 100).toInt()}%'
        : '—';
    final elements = (_visionResult?['detected_elements'] as List?)?.join(', ') ?? 'Processing...';
    final description = _visionResult?['description'] ?? 'Gemini Vision analyzing image...';

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    child: _visionResult == null && !_isSubmitting
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.description, color: kPrimaryTeal, size: 20),
                                  const SizedBox(width: 8),
                                  Text('Add Text Details', style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.bold, color: kPrimaryTeal)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _descriptionController,
                                maxLines: 4,
                                decoration: InputDecoration(
                                  hintText: 'Describe the damage or incident details here... (e.g. road blocked, flooded area) / تفصیلات درج کریں...',
                                  hintStyle: const TextStyle(color: Colors.black54, fontSize: 13),
                                  fillColor: Colors.white.withValues(alpha: 0.4),
                                  filled: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                style: const TextStyle(color: Colors.black87, fontSize: 14),
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _capturedImage = null;
                                  });
                                },
                                icon: const Icon(Icons.refresh, size: 16),
                                label: const Text('Retake Photo'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.black87,
                                  side: const BorderSide(color: Colors.black38),
                                ),
                              ),
                            ],
                          )
                        : _visionResult == null
                            ? const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CircularProgressIndicator(color: kPrimaryTeal),
                                    SizedBox(height: 16),
                                    Text('Gemini Vision assessing damage...', style: TextStyle(color: kPrimaryTeal, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.auto_awesome, color: kPrimaryTeal, size: 20),
                                      const SizedBox(width: 8),
                                      Text('Gemini Vision Analysis', style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.bold, color: kPrimaryTeal)),
                                      const Spacer(),
                                      Text('Confidence: $confidence', style: GoogleFonts.nunito(fontSize: 12, color: kPrimaryTeal)),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text('Crisis Type: $crisisType', style: GoogleFonts.nunito(fontSize: 14, color: Colors.black87)),
                                  const SizedBox(height: 4),
                                  Text('Severity: $severity ($priority)', style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.bold, color: kEmergencyRed)),
                                  const SizedBox(height: 4),
                                  Text('Detected: $elements', style: GoogleFonts.nunito(fontSize: 13, color: Colors.black87)),
                                  const SizedBox(height: 6),
                                  Text(description, style: GoogleFonts.nunito(fontSize: 12, color: Colors.black54)),
                                ],
                              ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _analyzeAndSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryTeal,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isSubmitting
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Send to Gemini Pipeline →', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
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
