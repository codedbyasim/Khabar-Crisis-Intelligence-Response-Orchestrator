import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:khabar/screens/incident_tracker_screen.dart';
import 'package:khabar/theme/app_colors.dart';
import 'package:khabar/api_config.dart';
import 'package:khabar/utils/location_helper.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:khabar/utils/connectivity_service.dart';
import 'package:khabar/utils/web_helper.dart';
import 'package:khabar/theme/language_provider.dart';


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

  bool _isProcessing = false;
  bool _isRecording = true;
  double _lat = 33.6844;
  double _lng = 73.0479;
  XFile? _attachedImage;

  GoogleMapController? _mapController;
  late LatLng _markerPosition;
  bool _isFetchingLocation = false;
  String? _locationStatus;

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    final String region = LanguageProvider().region;
    final bool isRawalpindi = region.toLowerCase().contains('rawalpindi');
    _markerPosition = LatLng(
      isRawalpindi ? 33.5651 : 33.6844,
      isRawalpindi ? 73.0169 : 73.0479,
    );

    _startRecording();
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
        debugPrint('[GPS] Voice screen location resolved to ($_lat, $_lng) via source: ${result.source}');
      }
    } catch (e) {
      debugPrint("Voice screen GPS error: $e");
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
    _mapController?.dispose();
    super.dispose();
  }

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

  Future<void> _pickAndProcessAudioFile() async {
    try {
      if (_isRecording) {
        await _audioRecorder.stop();
      }
      _animationController.stop();

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _recordPath = result.files.single.path!;
          _isRecording = false;
        });
      }
    } catch (e) {
      debugPrint("Pick audio error: $e");
    }
  }

  Future<void> _stopRecordingAndReview() async {
    _animationController.stop();
    try {
      final path = await _audioRecorder.stop();
      if (path != null) {
        setState(() {
          _recordPath = path;
          _isRecording = false;
        });
      }
    } catch (e) {
      debugPrint("Stop recording error: $e");
    }
  }

  Future<void> _submitReport() async {
    if (_recordPath == null) return;
    setState(() => _isProcessing = true);

    try {
      var request = http.MultipartRequest('POST', Uri.parse('${ApiConfig.baseUrl}/report/voice'));
      request.files.add(await http.MultipartFile.fromPath('audio', _recordPath!));
      request.fields['lat'] = _markerPosition.latitude.toString();
      request.fields['lng'] = _markerPosition.longitude.toString();
      if (_attachedImage != null) {
        request.files.add(await http.MultipartFile.fromPath('image', _attachedImage!.path));
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Voice signal processed. Triggering AI Response Pipeline!'),
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
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundLight,
      appBar: AppBar(
        title: const Text('Live Voice Report', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: kBackgroundLight,
        surfaceTintColor: Colors.transparent,
      ),
      body: _isProcessing
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: kPrimaryTeal),
                  const SizedBox(height: 16),
                  Text('Sending to Gemini AI Pipeline...', style: GoogleFonts.nunito(color: kPrimaryTeal, fontWeight: FontWeight.bold)),
                ],
              ),
            )
          : _isRecording
              ? Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      // Active Waveform
                      Expanded(
                        flex: 3,
                        child: Center(
                          child: AnimatedBuilder(
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
                      
                      // Recording Status Card
                      Expanded(
                        flex: 2,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: kCardWhite,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.circle, color: Colors.red, size: 8),
                                        const SizedBox(width: 4),
                                        Text('REC', style: GoogleFonts.nunito(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text('Speak clearly to report the emergency details...', style: GoogleFonts.nunito(fontSize: 14, color: kTextDark)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Live Recording Controls
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Gallery Upload
                          InkWell(
                            onTap: _pickAndProcessAudioFile,
                            borderRadius: BorderRadius.circular(28),
                            child: Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: const Icon(Icons.audio_file_outlined, color: kPrimaryTeal, size: 26),
                            ),
                          ),
                          const SizedBox(width: 36),
                          
                          // Stop and Review Button
                          InkWell(
                            onTap: _stopRecordingAndReview,
                            borderRadius: BorderRadius.circular(40),
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: kEmergencyRed,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(color: kEmergencyRed.withValues(alpha: 0.4), blurRadius: 15, offset: const Offset(0, 5)),
                                ],
                              ),
                              child: const Icon(Icons.stop_rounded, color: Colors.white, size: 40),
                            ),
                          ),
                          const SizedBox(width: 92), // Symmetry padding spacer
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Voice Preview Card
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        color: kCardWhite,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: kPrimaryTeal.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.mic, color: kPrimaryTeal),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Voice Report Recorded', style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.bold, color: kTextDark)),
                                    Text('Audio ready for transcription', style: GoogleFonts.nunito(fontSize: 12, color: kTextLight)),
                                  ],
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _recordPath = null;
                                    _isRecording = true;
                                  });
                                  _startRecording();
                                  _animationController.repeat(reverse: true);
                                },
                                icon: const Icon(Icons.refresh, size: 14),
                                label: const Text('Re-record', style: TextStyle(fontSize: 12)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: kEmergencyRed,
                                  side: BorderSide(color: kEmergencyRed.withValues(alpha: 0.3)),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Attached Image Section (Optional)
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
                                  ? Text('Attach Image (Optional)', style: GoogleFonts.nunito(fontSize: 14, color: Colors.grey.shade600))
                                  : Row(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.file(File(_attachedImage!.path), width: 45, height: 45, fit: BoxFit.cover),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text('Photo attached successfully', style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.bold, color: kTextDark), overflow: TextOverflow.ellipsis),
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
                                style: TextButton.styleFrom(foregroundColor: kPrimaryTeal, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                                child: const Text('Choose Photo'),
                              ),
                          ],
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
      bottomNavigationBar: _isRecording
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _submitReport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryTeal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Send to Gemini Pipeline →', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
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
      final double heightScale = (sin(phase + (animationValue * pi * 2)) + 1) / 2;

      final double finalHeight = size.height * 0.2 + (size.height * 0.8 * heightScale * (0.5 + noise * 0.5));

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
