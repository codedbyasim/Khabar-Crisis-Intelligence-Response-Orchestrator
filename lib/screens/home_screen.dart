import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:marquee/marquee.dart';
import 'package:khabar/theme/app_colors.dart';
import 'package:khabar/theme/language_provider.dart';
import 'package:khabar/theme/translations.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:khabar/utils/connectivity_service.dart';
import 'package:khabar/api_config.dart';

import 'package:khabar/screens/ai_chat_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  String _selectedLanguage = 'English';
  late AnimationController _pulseController;

  Map<String, dynamic>? _weatherData;
  List<dynamic> _newsArticles = [];
  bool _isLoadingWeather = true;
  bool _isLoadingNews = true;

  @override
  void initState() {
    super.initState();
    _selectedLanguage = LanguageProvider().language;
    LanguageProvider().addListener(_onLanguageChanged);
    ConnectivityService().addListener(_onConnectivityChanged);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _fetchWeatherData();
    _fetchNewsData();
  }

  Future<void> _fetchWeatherData() async {
    if (!ConnectivityService().value) {
      if (mounted) {
        setState(() {
          _weatherData = {
            "current": {
              "temperature_2m": 31.0,
              "wind_speed_10m": 8.5,
              "weather_code": 3 // partly cloudy
            }
          };
          _isLoadingWeather = false;
        });
      }
      return;
    }

    try {
      final String region = LanguageProvider().region;
      final bool isRawalpindi = region.toLowerCase().contains('rawalpindi');
      final double lat = isRawalpindi ? 33.5651 : 33.6844;
      final double lng = isRawalpindi ? 73.0169 : 73.0479;

      final url = 'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lng&current=temperature_2m,weather_code,wind_speed_10m&timezone=auto';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _weatherData = jsonDecode(response.body);
            _isLoadingWeather = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingWeather = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingWeather = false);
    }
  }

  Future<void> _fetchNewsData() async {
    if (!ConnectivityService().value) {
      if (mounted) {
        setState(() {
          _newsArticles = [
            {
              "title": "Offline Mode active: Local response teams are alert in twin cities",
              "source": {"name": "Khabar System Alert"},
              "date": "Just now"
            },
            {
              "title": "Nullah Lai Rawalpindi water level monitored via local telemetry sensors",
              "source": {"name": "WASA Offline Telemetry"},
              "date": "10 mins ago"
            }
          ];
          _isLoadingNews = false;
        });
      }
      return;
    }

    try {
      final url = '${ApiConfig.baseUrl}/live-news';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _newsArticles = data;
            _isLoadingNews = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingNews = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingNews = false);
    }
  }



  void _onLanguageChanged() {
    setState(() {
      _selectedLanguage = LanguageProvider().language;
    });
  }

  void _onConnectivityChanged() {
    if (mounted) {
      setState(() {
        _isLoadingWeather = true;
        _isLoadingNews = true;
      });
      _fetchWeatherData();
      _fetchNewsData();
    }
  }

  @override
  void dispose() {
    LanguageProvider().removeListener(_onLanguageChanged);
    ConnectivityService().removeListener(_onConnectivityChanged);
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          _fetchWeatherData();
          _fetchNewsData();
        },
        color: kPrimaryTeal,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            _buildEmergencyMarquee(),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildLocalSettingsCard(),
                  const SizedBox(height: 20),
                  
                  // Help with AI Chat Card (FR-Chat)
                  _buildHelpWithAiCard(),
                  const SizedBox(height: 24),

                  // Today's Weather Card (FR-Weather)
                  _buildWeatherSection(),
                  const SizedBox(height: 24),

                  // Today's News Card (FR-News)
                  _buildTodayNewsSection(),
                  const SizedBox(height: 24),

                  // Removed "Track My Help Requests" as per user request
                  _buildStatsRow(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildEmergencyMarquee() {
    String alertText = AppTranslations.t('emergency_marquee', _selectedLanguage);
    if (_newsArticles.isNotEmpty) {
      final article = _newsArticles.first;
      final title = article['title'] ?? '';
      if (title.isNotEmpty) {
        if (_selectedLanguage == 'اردو') {
          alertText = "تازہ ترین ہنگامی الرٹ: $title     ***     ";
        } else {
          alertText = "LATEST EMERGENCY ALERT: $title     ***     ";
        }
      }
    }

    return Container(
      height: 40,
      color: kEmergencyRed,
      child: Marquee(
        text: alertText,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
        scrollAxis: Axis.horizontal,
        crossAxisAlignment: CrossAxisAlignment.center,
        blankSpace: 100.0,
        velocity: 50.0,
        startPadding: 10.0,
      ),
    );
  }

  Widget _buildLocalSettingsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    AppTranslations.t('local_settings', _selectedLanguage),
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: kTextDark,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                // Real-time ONLINE/OFFLINE indicator
                ValueListenableBuilder<bool>(
                  valueListenable: ConnectivityService(),
                  builder: (context, isOnline, child) {
                    final statusColor = isOnline ? Colors.green : Colors.red;
                    final statusLabel = isOnline ? "ONLINE" : "OFFLINE";
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, color: statusColor, size: 8),
                          const SizedBox(width: 4),
                          Text(
                            statusLabel,
                            style: GoogleFonts.nunito(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                const Icon(Icons.circle, color: Colors.green, size: 8),
                const SizedBox(width: 4),
                Text(
                  AppTranslations.t('location_active', _selectedLanguage),
                  style: GoogleFonts.nunito(fontSize: 12, color: Colors.green),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'اردو',
                    label: Text('اردو', style: TextStyle(fontSize: 13)),
                  ),
                  ButtonSegment(
                    value: 'English',
                    label: Text('English', style: TextStyle(fontSize: 13)),
                  ),
                  ButtonSegment(
                    value: 'Roman Urdu',
                    label: Text('Roman Urdu', style: TextStyle(fontSize: 13)),
                  ),
                ],
                selected: {_selectedLanguage},
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() {
                    _selectedLanguage = newSelection.first;
                  });
                  LanguageProvider().setLanguage(newSelection.first);
                },
                style: ButtonStyle(visualDensity: VisualDensity.compact),
              ),
            ),
          ],
        ),
      ),
    );
  }


  // ── Stats Row ──
  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            Icons.map_outlined,
            '14 km',
            AppTranslations.t('coverage_area', _selectedLanguage),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard(
            Icons.groups_outlined,
            '4',
            AppTranslations.t('active_agents', _selectedLanguage),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard(
            Icons.timer_outlined,
            '< 3s',
            AppTranslations.t('response_time', _selectedLanguage),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(IconData icon, String value, String label) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: kPrimaryTeal, size: 22),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: kPrimaryTeal,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.nunito(fontSize: 11, color: kTextLight),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── Today's News (Aaj ki Khabar - REAL DATA) ──
  Widget _buildTodayNewsSection() {
    String newsHeader = "Today's News (Crisis Feed)";
    if (_selectedLanguage == 'اردو') {
      newsHeader = "آج کی خبریں (ہنگامی حالات)";
    } else if (_selectedLanguage == 'Roman Urdu') {
      newsHeader = "Aaj ki Khabar (Crisis Feed)";
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.newspaper, color: kPrimaryTeal, size: 22),
            const SizedBox(width: 8),
            Text(
              newsHeader,
              style: GoogleFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: kTextDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Card(
          elevation: 1.5,
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: _isLoadingNews
                ? const Center(child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(color: kPrimaryTeal),
                  ))
                : _newsArticles.isEmpty
                    ? Center(child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'No local news available at the moment.',
                          style: GoogleFonts.nunito(color: kTextLight),
                        ),
                      ))
                    : Column(
                        children: List.generate(
                          _newsArticles.length > 2 ? 2 : _newsArticles.length,
                          (index) {
                            final article = _newsArticles[index];
                            final title = article['title'] ?? 'Emergency Report';
                            final rawSource = article['source'];
                            final String sourceName = rawSource is Map ? (rawSource['name'] ?? 'Local Source') : (rawSource?.toString() ?? 'Local Source');
                            final dateStr = article['date'] ?? '';
                            
                            // Determine basic icon and color based on title
                            IconData icon = Icons.campaign;
                            Color color = Colors.orange;
                            final lowerTitle = title.toLowerCase();
                            if (lowerTitle.contains('flood') || lowerTitle.contains('rain')) {
                              icon = Icons.water_drop; color = Colors.blue;
                            } else if (lowerTitle.contains('fire')) {
                              icon = Icons.local_fire_department; color = Colors.red;
                            } else if (lowerTitle.contains('traffic') || lowerTitle.contains('accident')) {
                              icon = Icons.traffic; color = Colors.orange;
                            }

                            return Column(
                              children: [
                                _buildNewsItem(
                                  title,
                                  sourceName,
                                  dateStr,
                                  icon,
                                  color,
                                ),
                                if (index == 0 && _newsArticles.length > 1)
                                  const Divider(height: 16),
                              ],
                            );
                          },
                        ),
                      ),
          ),
        ),
      ],
    );
  }

  Widget _buildNewsItem(String title, String desc, String time, IconData icon, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: kTextDark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: GoogleFonts.nunito(fontSize: 12, color: kTextLight),
              ),
              const SizedBox(height: 4),
              Text(
                time,
                style: GoogleFonts.nunito(fontSize: 10, color: kTextLight, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Islamabad & Rawalpindi Weather (REAL DATA from Open-Meteo) ──
  Widget _buildWeatherSection() {
    final String fullRegion = LanguageProvider().region;
    final bool isRawalpindi = fullRegion.toLowerCase().contains('rawalpindi');
    final String cityName = isRawalpindi ? 'Rawalpindi' : 'Islamabad';

    String weatherHeader = "Today's Weather Status";
    if (_selectedLanguage == 'اردو') {
      weatherHeader = "موسم کی صورتحال";
    } else if (_selectedLanguage == 'Roman Urdu') {
      weatherHeader = "Mausam ki Soort-e-haal";
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.cloudy_snowing, color: kPrimaryTeal, size: 22),
            const SizedBox(width: 8),
            Text(
              weatherHeader,
              style: GoogleFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: kTextDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [kPrimaryTeal, kPrimaryTeal.withValues(alpha: 0.85)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.all(16.0),
            child: _isLoadingWeather
                ? const Center(child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(color: Colors.white),
                  ))
                : _weatherData == null
                    ? Center(child: Text(
                        'Weather unavailable',
                        style: GoogleFonts.nunito(color: Colors.white70),
                      ))
                    : _buildWeatherContent(cityName),
          ),
        ),
      ],
    );
  }

  Widget _buildWeatherContent(String cityName) {
    final current = _weatherData!['current'] ?? {};
    final double tempC = (current['temperature_2m'] ?? 0.0).toDouble();
    final double windKmh = (current['wind_speed_10m'] ?? 0.0).toDouble();
    final int weatherCode = (current['weather_code'] ?? 0) as int;

    // Map WMO weather code to emoji + label
    String weatherLabel;
    IconData weatherIcon;
    if (weatherCode == 0) {
      weatherLabel = 'Clear Sky'; weatherIcon = Icons.wb_sunny;
    } else if (weatherCode <= 3) {
      weatherLabel = 'Partly Cloudy'; weatherIcon = Icons.cloud;
    } else if (weatherCode <= 49) {
      weatherLabel = 'Foggy'; weatherIcon = Icons.cloud;
    } else if (weatherCode <= 67) {
      weatherLabel = 'Rainy'; weatherIcon = Icons.umbrella;
    } else if (weatherCode <= 77) {
      weatherLabel = 'Snow'; weatherIcon = Icons.ac_unit;
    } else if (weatherCode <= 82) {
      weatherLabel = 'Heavy Showers'; weatherIcon = Icons.thunderstorm;
    } else {
      weatherLabel = 'Thunderstorm'; weatherIcon = Icons.thunderstorm;
    }

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                cityName,
                style: GoogleFonts.nunito(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                weatherLabel,
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.air, color: Colors.white70, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Wind: ${windKmh.toStringAsFixed(1)} km/h',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Column(
          children: [
            Icon(weatherIcon, color: Colors.white, size: 48),
            const SizedBox(height: 4),
            Text(
              '${tempC.toStringAsFixed(1)}°C',
              style: GoogleFonts.nunito(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Help with AI Chat Card ──
  Widget _buildHelpWithAiCard() {
    String helpTitle = "Help with Khabar Chatbot";
    String helpSubtitle = "Chat real-time for safety guidelines & live updates.";
    if (_selectedLanguage == 'اردو') {
      helpTitle = "خبر چیٹ بوٹ سے مدد";
      helpSubtitle = "حفاظتی رہنما خطوط اور براہ راست اپ ڈیٹس کے لیے چیٹ کریں۔";
    } else if (_selectedLanguage == 'Roman Urdu') {
      helpTitle = "Khabar Chatbot ki madad";
      helpSubtitle = "Safety guidelines aur live updates ke liye chat karein.";
    }

    return Card(
      elevation: 2.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AiChatScreen()),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kPrimaryTeal.withValues(alpha: 0.15), width: 1.5),
            color: Colors.white,
          ),
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: kPrimaryTeal.withValues(alpha: 0.12),
                child: const Icon(Icons.psychology, color: kPrimaryTeal, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      helpTitle,
                      style: GoogleFonts.nunito(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: kTextDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      helpSubtitle,
                      style: GoogleFonts.nunito(
                        fontSize: 12.5,
                        color: kTextLight,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: kPrimaryTeal, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
