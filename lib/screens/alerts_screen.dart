import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:khabar/theme/app_colors.dart';
import 'package:khabar/theme/language_provider.dart';
import 'package:khabar/theme/translations.dart';
import 'package:khabar/api_config.dart';

const String kGNewsApiKey = "";

class AlertItem {
  final String title;
  final String urduTitle;
  final String location;
  final String time;
  final IconData icon;
  final String severity; // P1, P3, P5
  final bool isPinned;
  final String? url; // Link to the original news report

  AlertItem({
    required this.title,
    required this.urduTitle,
    required this.location,
    required this.time,
    required this.icon,
    required this.severity,
    this.isPinned = false,
    this.url,
  });
}

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  bool _isLoading = false;
  List<AlertItem> _alerts = [];
  bool _isLiveFeed = false;
  final bool showStatusBanner = true;

  // Hand-crafted emergency offline alerts for immediate high-fidelity fallback (Islamabad & Rawalpindi only)
  final List<AlertItem> _mockAlerts = [
    AlertItem(
      title: 'Urban Flooding & Dewatering Dispatched',
      urduTitle: 'شہری سیلاب اور ڈی واٹرنگ پمپس روانہ',
      location: 'Sector G-11, Islamabad',
      time: '2 mins ago',
      icon: Icons.water_drop,
      severity: 'P1',
      isPinned: true,
    ),
    AlertItem(
      title: 'Monsoon Torrential Rain Forecast',
      urduTitle: 'مانسون کی شدید بارشوں کا امکان',
      location: 'Islamabad & Rawalpindi',
      time: '15 mins ago',
      icon: Icons.thunderstorm,
      severity: 'P3',
      isPinned: true,
    ),
    AlertItem(
      title: 'Fire Trucks Dispatched to Saddar Plaza',
      urduTitle: 'سدر پلازہ میں فائر بریگیڈ کی گاڑیوں کی روانگی',
      location: 'Saddar, Rawalpindi',
      time: '1 hour ago',
      icon: Icons.local_fire_department,
      severity: 'P1',
    ),
    AlertItem(
      title: 'Utility Rescue Crew Active',
      urduTitle: 'یوٹیلیٹی ریسکیو ٹیمیں سرگرم',
      location: 'Sector F-8, Islamabad',
      time: '3 hours ago',
      icon: Icons.build,
      severity: 'P3',
    ),
    AlertItem(
      title: 'Faizabad Slip Alert & Traffic Jam',
      urduTitle: 'فیض آباد سلپ الرٹ اور ٹریفک جام',
      location: 'Faizabad Interchange, Islamabad',
      time: '4 hours ago',
      icon: Icons.traffic,
      severity: 'P5',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fetchLiveNews();
  }

  /// Assign dynamic Icon based on title keywords
  IconData _getIconForTitle(String title) {
    final lowerTitle = title.toLowerCase();
    if (lowerTitle.contains('flood') ||
        lowerTitle.contains('rain') ||
        lowerTitle.contains('storm')) {
      return Icons.water;
    } else if (lowerTitle.contains('fire') ||
        lowerTitle.contains('explosion') ||
        lowerTitle.contains('blast')) {
      return Icons.local_fire_department;
    } else if (lowerTitle.contains('heat') ||
        lowerTitle.contains('summer') ||
        lowerTitle.contains('temperature')) {
      return Icons.thermostat;
    } else if (lowerTitle.contains('accident') ||
        lowerTitle.contains('traffic') ||
        lowerTitle.contains('road')) {
      return Icons.traffic;
    } else if (lowerTitle.contains('strike') ||
        lowerTitle.contains('protest') ||
        lowerTitle.contains('clash')) {
      return Icons.groups;
    }
    return Icons.campaign; // General announcement/alert megaphone
  }

  /// Assign dynamic Severity (P1 = Crisis, P3 = Hazard, P5 = Alert)
  String _getSeverityForTitle(String title) {
    final lowerTitle = title.toLowerCase();
    if (lowerTitle.contains('flood') ||
        lowerTitle.contains('fire') ||
        lowerTitle.contains('dead') ||
        lowerTitle.contains('blast')) {
      return 'P1';
    } else if (lowerTitle.contains('rain') ||
        lowerTitle.contains('warning') ||
        lowerTitle.contains('protest')) {
      return 'P3';
    }
    return 'P5';
  }

  DateTime? _parseRssDate(String dateStr) {
    try {
      final cleaned = dateStr.replaceAll(
        RegExp(r'^[A-Za-z]{3},\s*'),
        '',
      ); // Remove "Sun, "
      final parts = cleaned.split(RegExp(r'\s+'));
      if (parts.length >= 4) {
        final int day = int.parse(parts[0]);
        final String monthStr = parts[1].toLowerCase();
        final int year = int.parse(parts[2]);
        final timeParts = parts[3].split(':');
        final int hour = int.parse(timeParts[0]);
        final int minute = int.parse(timeParts[1]);

        int month = 1;
        const months = [
          'jan',
          'feb',
          'mar',
          'apr',
          'may',
          'jun',
          'jul',
          'aug',
          'sep',
          'oct',
          'nov',
          'dec',
        ];
        final index = months.indexOf(monthStr.substring(0, 3));
        if (index != -1) month = index + 1;

        return DateTime(year, month, day, hour, minute);
      }
    } catch (_) {}
    return null;
  }

  Future<void> _fetchLiveNews() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/live-news');
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List results = json.decode(response.body);
        List<AlertItem> loadedAlerts = [];

        for (var i = 0; i < results.length; i++) {
          final article = results[i];
          final String title = article['title'] ?? 'Emergency Report';
          final String urduTitle = article['urduTitle'] ?? title;
          final String sourceName = article['source'] ?? 'Local Source';
          final String dateStr = article['date'] ?? '';
          final String? link = article['link'];

          loadedAlerts.add(
            AlertItem(
              title: title,
              urduTitle: urduTitle,
              location: sourceName,
              time: dateStr,
              icon: _getIconForTitle(title),
              severity: _getSeverityForTitle(title),
              isPinned: i == 0,
              url: link,
            ),
          );
        }

        if (loadedAlerts.isNotEmpty) {
          setState(() {
            _alerts = loadedAlerts;
            _isLiveFeed = true;
            _isLoading = false;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint('Backend live-news fetch error: $e');
    }

    // Roll back to RSS backup if query fails
    await _fetchRssBackup();
    return;
  }

  Future<void> _fetchRssBackup() async {
    try {
      final String region = LanguageProvider().region.split(',').first.trim();
      final url = Uri.parse(
        'https://news.google.com/rss/search?q=${Uri.encodeComponent(region)}%20(emergency%20OR%20floods%20OR%20rain%20OR%20weather%20OR%20crisis%20OR%20disaster)%20when:7d&hl=en-PK&gl=PK&ceid=PK:en',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final body = response.body;

        final RegExp itemRegExp = RegExp(r'<item>([\s\S]*?)</item>');
        final RegExp titleRegExp = RegExp(r'<title>(.*?)</title>');
        final RegExp linkRegExp = RegExp(r'<link>(.*?)</link>');
        final RegExp pubDateRegExp = RegExp(r'<pubDate>(.*?)</pubDate>');

        final List<AlertItem> loadedAlerts = [];
        final matches = itemRegExp.allMatches(body).toList();
        final int count = matches.length > 12 ? 12 : matches.length;

        for (var i = 0; i < count; i++) {
          final itemXml = matches[i].group(1) ?? '';

          var title = 'Pakistan Emergency Report';
          final titleMatch = titleRegExp.firstMatch(itemXml);
          if (titleMatch != null) {
            title = titleMatch.group(1) ?? 'Pakistan Emergency Report';
            title = title
                .replaceAll('&amp;', '&')
                .replaceAll('&quot;', '"')
                .replaceAll('&apos;', "'")
                .replaceAll('&lt;', '<')
                .replaceAll('&gt;', '>');
          }

          var link = '';
          final linkMatch = linkRegExp.firstMatch(itemXml);
          if (linkMatch != null) {
            link = linkMatch.group(1) ?? '';
          }

          var pubDate = '';
          final pubDateMatch = pubDateRegExp.firstMatch(itemXml);
          if (pubDateMatch != null) {
            pubDate = pubDateMatch.group(1) ?? '';
          }

          String sourceName = 'Local Source';
          String cleanTitle = title;
          final dashIndex = title.lastIndexOf(' - ');
          if (dashIndex != -1) {
            cleanTitle = title.substring(0, dashIndex).trim();
            sourceName = title.substring(dashIndex + 3).trim();
          }

          String relativeTime = 'Recently';
          try {
            if (pubDate.isNotEmpty) {
              final dateTime = _parseRssDate(pubDate) ?? DateTime.now();
              final diff = DateTime.now().difference(dateTime);
              if (diff.inMinutes < 60) {
                relativeTime = '${diff.inMinutes} mins ago';
              } else if (diff.inHours < 24) {
                relativeTime = '${diff.inHours} hours ago';
              } else {
                relativeTime = '${diff.inDays} days ago';
              }
            }
          } catch (_) {}

          String urduTitle = 'قومی ہنگامی الرٹ رپورٹ';
          final lowerTitle = cleanTitle.toLowerCase();
          if (lowerTitle.contains('rain') || lowerTitle.contains('storm')) {
            urduTitle = 'شدید بارش اور طوفان کا الرٹ';
          } else if (lowerTitle.contains('flood') ||
              lowerTitle.contains('water')) {
            urduTitle = 'سائیکلون اور سیلاب کا خطرہ';
          } else if (lowerTitle.contains('heat') ||
              lowerTitle.contains('hot')) {
            urduTitle = 'شدید گرمی کی لہر کی وارننگ';
          } else if (lowerTitle.contains('fire')) {
            urduTitle = 'آگ لگنے کا ہنگامی واقعہ';
          } else if (lowerTitle.contains('accident') ||
              lowerTitle.contains('crash')) {
            urduTitle = 'ٹریفک حادثہ کی رپورٹ';
          } else if (lowerTitle.contains('earthquake') ||
              lowerTitle.contains('quake')) {
            urduTitle = 'زلزلہ کے جھٹکے محسوس کیے گئے';
          }

          loadedAlerts.add(
            AlertItem(
              title: cleanTitle,
              urduTitle: urduTitle,
              location: sourceName,
              time: relativeTime,
              icon: _getIconForTitle(cleanTitle),
              severity: _getSeverityForTitle(cleanTitle),
              isPinned: i == 0,
              url: link.isNotEmpty ? link : null,
            ),
          );
        }

        setState(() {
          _alerts = loadedAlerts.isNotEmpty
              ? loadedAlerts
              : List.from(_mockAlerts);
          _isLiveFeed = loadedAlerts.isNotEmpty;
          _isLoading = false;
        });
        return;
      }
    } catch (_) {}

    await _fetchBackendIncidentsAsAlerts();
  }

  Future<void> _fetchBackendIncidentsAsAlerts() async {
    try {
      final url = '${ApiConfig.baseUrl}/incidents';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List list = data['incidents'] ?? [];
        if (list.isNotEmpty) {
          final List<AlertItem> incidentAlerts = [];
          for (var item in list) {
            final String title = item['incident_type'] ?? 'Emergency Report';
            final String severity = item['priority'] ?? 'P1';
            final String status = item['status'] ?? 'Active';
            final String locationName = item['location']?['address'] ?? 'Islamabad';
            
            String urduTitle = 'قومی ہنگامی الرٹ رپورٹ';
            final lowerTitle = title.toLowerCase();
            if (lowerTitle.contains('rain') || lowerTitle.contains('storm')) {
              urduTitle = 'شدید بارش اور طوفان کا الرٹ';
            } else if (lowerTitle.contains('flood') || lowerTitle.contains('water')) {
              urduTitle = 'سائیکلون اور سیلاب کا خطرہ';
            } else if (lowerTitle.contains('fire')) {
              urduTitle = 'آگ لگنے کا ہنگامی واقعہ';
            }
            
            incidentAlerts.add(
              AlertItem(
                title: 'Live: $title ($status)',
                urduTitle: urduTitle,
                location: locationName,
                time: 'Just now',
                icon: _getIconForTitle(title),
                severity: severity,
                isPinned: severity == 'P1',
              ),
            );
          }
          setState(() {
            _alerts = incidentAlerts;
            _isLiveFeed = true;
            _isLoading = false;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint('Error fetching backend alerts: $e');
    }

    setState(() {
      _alerts = List.from(_mockAlerts);
      _isLiveFeed = false;
      _isLoading = false;
    });
  }

  Color _getSeverityColor(String severity) {
    switch (severity) {
      case 'P1':
        return kEmergencyRed;
      case 'P3':
        return Colors.orange;
      case 'P5':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentLang = LanguageProvider().language;

    return Scaffold(
      backgroundColor: kBackgroundLight,
      appBar: AppBar(
        title: Text(
          AppTranslations.t('alerts', currentLang),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: kBackgroundLight,
        surfaceTintColor: Colors.transparent,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchLiveNews,
        color: kPrimaryTeal,
        child: _isLoading
            ? _buildShimmerLoading()
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(
                  left: 16.0,
                  right: 16.0,
                  top: 16.0,
                  bottom: 90.0,
                ),
                itemCount: _alerts.length + (showStatusBanner ? 1 : 0),
                itemBuilder: (context, index) {
                  // Show the API key setup banner at the top
                  if (showStatusBanner && index == 0) {
                    return _buildApiKeyTipBanner();
                  }

                  final alertIndex = showStatusBanner ? index - 1 : index;
                  final alert = _alerts[alertIndex];
                  final severityColor = _getSeverityColor(alert.severity);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: alert.isPinned
                              ? const Color(0xFFFFEBEE)
                              : kCardWhite,
                          border: alert.isPinned
                              ? const Border(
                                  left: BorderSide(
                                    color: kEmergencyRed,
                                    width: 4,
                                  ),
                                )
                              : null,
                          boxShadow: [
                            if (!alert.isPinned)
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              if (alert.url != null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Opening report: ${alert.title}',
                                    ),
                                    backgroundColor: kPrimaryTeal,
                                  ),
                                );
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: severityColor.withValues(
                                        alpha: 0.1,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      alert.icon,
                                      color: severityColor,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                currentLang == 'اردو'
                                                    ? alert.urduTitle
                                                    : alert.title,
                                                style: GoogleFonts.nunito(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold,
                                                  color: kTextDark,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            if (alert.isPinned)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: kEmergencyRed,
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  alert.severity,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.location_on,
                                              size: 14,
                                              color: Colors.grey,
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                alert.location,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              alert.time,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildApiKeyTipBanner() {
    final bool isUsingNewsData =
        kGNewsApiKey.contains("newsdata.io") || kGNewsApiKey.contains("pub_");
    final bool isUsingGNews =
        !isUsingNewsData &&
        kGNewsApiKey != "YOUR_GNEWS_API_KEY_HERE" &&
        kGNewsApiKey.isNotEmpty;

    String bannerTitle = 'Pakistan News & Weather Alerts Feed';
    String bannerSubtitle =
        'Currently running in Offline Mock mode. To pull real emergency news from Pakistan sources, register an API key at gnews.io or newsdata.io and insert it at the top of alerts_screen.dart.';

    if (_isLiveFeed) {
      if (isUsingNewsData) {
        bannerTitle = '🌐 Live NewsData.io Active';
        bannerSubtitle =
            'Successfully connected to NewsData.io live Pakistan feed. Displaying verified real-time emergency events.';
      } else if (isUsingGNews) {
        bannerTitle = '🌐 Live GNews API Active';
        bannerSubtitle =
            'Successfully connected to GNews live API. Displaying verified real-time emergency events.';
      } else {
        bannerTitle = '⚡ Live Pakistan Emergency Feed Active';
        bannerSubtitle =
            'Successfully aggregated live Pakistan crisis news, weather alerts, and rains from Google News.';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _isLiveFeed
            ? const Color(0xFFE0F2F1)
            : kPrimaryTeal.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isLiveFeed
              ? const Color(0xFF80CBC4)
              : kPrimaryTeal.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _isLiveFeed ? Icons.wifi_tethering : Icons.info_outline,
            color: _isLiveFeed ? const Color(0xFF00796B) : kPrimaryTeal,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bannerTitle,
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: _isLiveFeed ? const Color(0xFF00796B) : kPrimaryTeal,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  bannerSubtitle,
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    color: _isLiveFeed ? const Color(0xFF004D40) : kTextLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Container(
          height: 120,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
        );
      },
    );
  }
}
