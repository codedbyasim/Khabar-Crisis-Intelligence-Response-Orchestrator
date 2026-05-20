import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:khabar/screens/incident_tracker_screen.dart';
import 'package:khabar/theme/app_colors.dart';
import 'package:khabar/api_config.dart';

class VoiceReportScreen extends StatefulWidget {
  const VoiceReportScreen({super.key});

  @override
  State<VoiceReportScreen> createState() => _VoiceReportScreenState();
}

class _VoiceReportScreenState extends State<VoiceReportScreen>
    with SingleTickerProviderStateMixin {
  late final AudioRecorder _audioRecorder;
  late final AnimationController _animationController;
  String? _recordPath;
  final ScrollController _scrollController = ScrollController();

  String _transcriptionText = "Listening to your voice...\n";
  bool _isProcessing = false;
  bool _isRecording = true;
  double _lat = 33.6844;
  double _lng = 73.0479;
  XFile? _attachedImage;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Attach Image'),
        content: const Text('Select image source:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, ImageSource.camera),
            child: const Text('Camera'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ImageSource.gallery),
            child: const Text('Gallery'),
          ),
        ],
      ),
    );
    if (source != null) {
      final picked = await picker.pickImage(source: source);
      if (picked != null) {
        setState(() {
          _attachedImage = picked;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    _startRecording();
    _fetchDeviceLocation();
  }

  Future<void> _fetchDeviceLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (mounted) {
        setState(() {
          _lat = position.latitude;
          _lng = position.longitude;
        });
      }
    } catch (e) {
      debugPrint("Voice screen GPS error: $e");
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getApplicationDocumentsDirectory();
        _recordPath = '${dir.path}/khabar_voice_report_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: _recordPath!,
        );
      } else {
        setState(() {
          _transcriptionText = "Microphone permission denied.\n";
          _isRecording = false;
        });
      }
    } catch (e) {
      debugPrint("Record error: $e");
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _audioRecorder.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _stopAndProcess() async {
    _animationController.stop();
    setState(() {
      _isRecording = false;
      _isProcessing = true;
      _transcriptionText = "Recording stopped. Uploading audio to Gemini Speech for real-time transcription...\n";
    });

    try {
      final path = await _audioRecorder.stop();
      if (path != null) {
        var request = http.MultipartRequest('POST', Uri.parse('${ApiConfig.baseUrl}/report/voice'));
        request.files.add(await http.MultipartFile.fromPath('audio', path));
        request.fields['lat'] = _lat.toString();
        request.fields['lng'] = _lng.toString();
        if (_attachedImage != null) {
          request.files.add(await http.MultipartFile.fromPath('image', _attachedImage!.path));
        }

        var streamedResponse = await request.send();
        var response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (mounted) {
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    IncidentTrackerScreen(incidentData: data),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
              ),
            );
          }
        } else {
          throw Exception('Server error: ${response.statusCode}');
        }
      } else {
        throw Exception('Audio path is null');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _transcriptionText += "\nFailed to upload audio: $e";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundLight,
      appBar: AppBar(
        title: const Text('Live Voice Report',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: kBackgroundLight,
        surfaceTintColor: Colors.transparent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Waveform
            Expanded(
              flex: 2,
              child: Center(
                child: _isProcessing
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(color: kPrimaryTeal),
                          const SizedBox(height: 16),
                          Text('Sending to Gemini AI Pipeline...',
                              style: GoogleFonts.nunito(
                                  color: kPrimaryTeal, fontWeight: FontWeight.bold)),
                        ],
                      )
                    : AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, child) {
                          return CustomPaint(
                            size: const Size(double.infinity, 150),
                            painter: WaveformPainter(_animationController.value),
                          );
                        },
                      ),
              ),
            ),

            // Transcription Box
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: kCardWhite,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isRecording ? Icons.transcribe : Icons.check_circle,
                          color: _isRecording ? kPrimaryTeal : Colors.green,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isRecording ? 'Live Transcription' : 'Recording Complete',
                          style: GoogleFonts.nunito(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: kTextDark,
                          ),
                        ),
                        if (_isRecording) ...[
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.circle, color: Colors.red, size: 8),
                                const SizedBox(width: 4),
                                Text('REC',
                                    style: GoogleFonts.nunito(
                                        color: Colors.red,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ]
                      ],
                    ),
                    const Divider(height: 24),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        child: Text(
                          _transcriptionText,
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            color: kTextDark,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Attached Image Section
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: kCardWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    _attachedImage == null ? Icons.add_a_photo_outlined : Icons.image_outlined,
                    color: _attachedImage == null ? Colors.grey : kPrimaryTeal,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _attachedImage == null
                        ? Text(
                            'Attach Image (Optional)',
                            style: GoogleFonts.nunito(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          )
                        : Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(_attachedImage!.path),
                                  width: 45,
                                  height: 45,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Photo attached successfully',
                                  style: GoogleFonts.nunito(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: kTextDark,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.cancel, color: Colors.grey, size: 20),
                                onPressed: () {
                                  setState(() {
                                    _attachedImage = null;
                                  });
                                },
                              ),
                            ],
                          ),
                  ),
                  if (_attachedImage == null)
                    TextButton(
                      onPressed: _pickImage,
                      style: TextButton.styleFrom(
                        foregroundColor: kPrimaryTeal,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      child: const Text('Choose Photo'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Stop Button
            Column(
              children: [
                InkWell(
                  onTap: (_isProcessing || !_isRecording) ? null : _stopAndProcess,
                  borderRadius: BorderRadius.circular(40),
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: _isProcessing ? Colors.grey : kEmergencyRed,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (_isProcessing ? Colors.grey : kEmergencyRed)
                              .withValues(alpha: 0.4),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Icon(
                      _isProcessing ? Icons.hourglass_top : Icons.stop_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _isProcessing
                      ? 'Processing...'
                      : _isRecording
                          ? 'Stop & Process Signal'
                          : 'Signal Sent ✓',
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _isProcessing ? Colors.grey : kEmergencyRed,
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class WaveformPainter extends CustomPainter {
  final double animationValue;
  final Random random = Random(42);

  WaveformPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final int barCount = 30;
    final double barWidth = size.width / (barCount * 2);
    final double spacing = barWidth;

    final Paint paint = Paint()
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round;

    final Rect rect = Offset.zero & size;
    paint.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Colors.teal, Colors.green, Colors.yellow],
    ).createShader(rect);

    for (int i = 0; i < barCount; i++) {
      final double noise = random.nextDouble();
      final double phase = i / barCount * pi * 4;
      final double heightScale =
          (sin(phase + (animationValue * pi * 2)) + 1) / 2;

      final double finalHeight =
          size.height * 0.2 +
          (size.height * 0.8 * heightScale * (0.5 + noise * 0.5));

      final double x = i * (barWidth + spacing) + spacing / 2;
      final double y = (size.height - finalHeight) / 2;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, finalHeight),
          Radius.circular(barWidth / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
