import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:marquee/marquee.dart';
import 'package:khabar/theme/app_colors.dart';
import 'package:khabar/theme/language_provider.dart';
import 'package:khabar/theme/translations.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:khabar/screens/incident_tracker_screen.dart';
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
  bool _isAiStatusExpanded = false;
  bool _isReportsExpanded = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  List<dynamic> _incidents = [];
  bool _isLoadingIncidents = false;

  Map<String, dynamic>? _weatherData;
  List<dynamic> _newsArticles = [];
  bool _isLoadingWeather = true;
  bool _isLoadingNews = true;

  @override
  void initState() {
    super.initState();
    _selectedLanguage = LanguageProvider().language;
    LanguageProvider().addListener(_onLanguageChanged);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _fetchIncidents();
    _fetchWeatherData();
    _fetchNewsData();
  }

  Future<void> _fetchWeatherData() async {
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
    try {
      const apiKey = 'e1310da5ab09d0c4bfb32e0bfc5e514c8c3a29248d2173eb666546c34fc4ca5c';
      final String region = LanguageProvider().region.split(',').first.trim();
      final url = 'https://serpapi.com/search.json?engine=google_news&q=${Uri.encodeComponent(region)}+Emergency+News&api_key=$apiKey';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _newsArticles = data['news_results'] ?? [];
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

  Future<void> _fetchIncidents() async {
    setState(() => _isLoadingIncidents = true);
    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/incidents')).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _incidents = data['incidents'];
        });
      }
    } catch (e) {
      debugPrint("Error fetching incidents: $e");
    } finally {
      if (mounted) setState(() => _isLoadingIncidents = false);
    }
  }

  void _onLanguageChanged() {
    setState(() {
      _selectedLanguage = LanguageProvider().language;
    });
  }

  @override
  void dispose() {
    LanguageProvider().removeListener(_onLanguageChanged);
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          _fetchIncidents();
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

                  Text(
                    'Track My Help Requests',
                    style: GoogleFonts.nunito(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: kTextDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildMySignalsCard(),
                  const SizedBox(height: 24),
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
    return Container(
      height: 40,
      color: kEmergencyRed,
      child: Marquee(
        text: AppTranslations.t('emergency_marquee', _selectedLanguage),
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
                const Icon(Icons.circle, color: Colors.green, size: 10),
                const SizedBox(width: 6),
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

  // ── Antigravity AI Card ──
  Widget _buildAntigravityAiCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          setState(() {
            _isAiStatusExpanded = !_isAiStatusExpanded;
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: kPrimaryTeal.withValues(alpha: 0.15),
                    child: const Icon(Icons.settings_suggest, color: kPrimaryTeal, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppTranslations.t('antigravity_ai', _selectedLanguage),
                          style: GoogleFonts.nunito(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: kTextDark,
                          ),
                        ),
                        Text(
                          AppTranslations.t('pipeline_status', _selectedLanguage),
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            color: kTextLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _isAiStatusExpanded ? 0.25 : 0.0,
                    duration: const Duration(milliseconds: 250),
                    child: const Icon(Icons.chevron_right, color: kTextLight, size: 24),
                  ),
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: _isAiStatusExpanded
                    ? _buildAiPipeline()
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAiPipeline() {
    return Padding(
      padding: const EdgeInsets.only(top: 20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildPipelineStep(Icons.radar, AppTranslations.t('detection', _selectedLanguage), false),
          _buildPipelineStep(Icons.bar_chart, AppTranslations.t('analysis', _selectedLanguage), true),
          _buildPipelineStep(Icons.lightbulb_outline, AppTranslations.t('planning', _selectedLanguage), false),
          _buildPipelineStep(Icons.bolt, AppTranslations.t('execution', _selectedLanguage), false),
        ],
      ),
    );
  }

  Widget _buildPipelineStep(IconData icon, String label, bool isActive) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? kPrimaryTeal : Colors.grey.shade200,
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: kPrimaryTeal.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            color: isActive ? Colors.white : kTextLight,
            size: 22,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 11,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? kPrimaryTeal : kTextLight,
          ),
        ),
      ],
    );
  }

  // ── My Signals Card ──
  Widget _buildMySignalsCard() {
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
                CircleAvatar(
                  radius: 22,
                  backgroundColor: kPrimaryTeal.withValues(alpha: 0.15),
                  child: const Icon(Icons.radar, color: kPrimaryTeal, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Live Emergency Tracking',
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: kTextDark,
                        ),
                      ),
                      Text(
                        'Tap an active request below to track help',
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          color: kTextLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSignalsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSignalsList() {
    if (_isLoadingIncidents) {
       return const Padding(
         padding: EdgeInsets.all(16.0),
         child: Center(child: CircularProgressIndicator(color: kPrimaryTeal)),
       );
    }
    
    if (_incidents.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 16.0),
        child: Text("No incidents reported yet. Create one via + Tab.", style: TextStyle(color: Colors.grey)),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: SizedBox(
        height: 90,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: _incidents.length,
          itemBuilder: (context, index) {
            final inc = _incidents[index];
            final id = inc['incident_id'].toString().length > 13 
                ? inc['incident_id'].toString().substring(0, 13) + '...'
                : inc['incident_id'].toString();
            final status = inc['status'] ?? 'UNKNOWN';
            Color color = Colors.orange;
            if (status == 'RESOLVED') color = Colors.green;
            else if (status == 'RESPONDING' || status == 'IN_PROGRESS' || status == 'MANUAL_REVIEW_REQUIRED') color = kEmergencyRed;
            
            return Padding(
              padding: const EdgeInsets.only(right: 10.0),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => IncidentTrackerScreen(incidentData: inc),
                    ),
                  );
                },
                child: _buildSignalItem(id, 'AI Processed', status, color),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSignalItem(
    String id,
    String location,
    String phase,
    Color phaseColor,
  ) {
    return Container(
      width: 155,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: kBackgroundLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            id,
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: kTextDark,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: phaseColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              phase,
              style: TextStyle(
                fontSize: 10,
                color: phaseColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.location_on, size: 12, color: kTextLight),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  location,
                  style: GoogleFonts.nunito(fontSize: 11, color: kTextLight),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── System Integrity Card ──
  Widget _buildSystemIntegrityCard() {
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
                Icon(Icons.shield_outlined, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Text(
                  AppTranslations.t('system_integrity', _selectedLanguage),
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: kTextDark,
                  ),
                ),
                const Spacer(),
                Text(
                  AppTranslations.t('last_sync', _selectedLanguage),
                  style: GoogleFonts.nunito(fontSize: 11, color: kTextLight),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildIntegrityRow(Icons.cloud_done, AppTranslations.t('api_connected', _selectedLanguage), true),
            const SizedBox(height: 10),
            _buildIntegrityRow(Icons.sync, AppTranslations.t('firebase_synced', _selectedLanguage), true),
            const SizedBox(height: 10),
            _buildIntegrityRow(Icons.memory, AppTranslations.t('ai_models_loaded', _selectedLanguage), true),
          ],
        ),
      ),
    );
  }

  Widget _buildIntegrityRow(IconData icon, String label, bool isOk) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: (isOk ? Colors.green : Colors.red).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: isOk ? Colors.green : Colors.red),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.nunito(fontSize: 14, color: kTextDark),
          ),
        ),
        Icon(
          isOk ? Icons.check_circle : Icons.error,
          size: 18,
          color: isOk ? Colors.green : Colors.red,
        ),
      ],
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
    if (_selectedLanguage == 'اردو') newsHeader = "آج کی خبریں (ہنگامی حالات)";
    else if (_selectedLanguage == 'Roman Urdu') newsHeader = "Aaj ki Khabar (Crisis Feed)";

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
                            final sourceName = article['source']?['name'] ?? 'Local Source';
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
    if (_selectedLanguage == 'اردو') weatherHeader = "موسم کی صورتحال";
    else if (_selectedLanguage == 'Roman Urdu') weatherHeader = "Mausam ki Soort-e-haal";

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
    String helpTitle = "Help with Antigravity AI";
    String helpSubtitle = "Chat real-time for safety guidelines & live updates.";
    if (_selectedLanguage == 'اردو') {
      helpTitle = "اینٹی گریوٹی اے آئی کی مدد";
      helpSubtitle = "حفاظتی رہنما خطوط اور براہ راست اپ ڈیٹس کے لیے چیٹ کریں۔";
    } else if (_selectedLanguage == 'Roman Urdu') {
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
