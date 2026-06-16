// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:khabar/api_config.dart';
import 'package:khabar/screens/auth_screen.dart';
import 'package:khabar/screens/incident_tracker_screen.dart';
import 'package:khabar/theme/app_colors.dart';
import 'package:khabar/theme/language_provider.dart';
import 'package:khabar/theme/translations.dart';
import 'package:khabar/utils/user_profile_helper.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _selectedLanguage = 'English';
  double _alertRadius = 5.0;
  bool _firebaseAlertsEnabled = true;
  bool _antigravityAiEnabled = true;
  String _selectedRegion = 'Islamabad, Capital Territory';

  late TextEditingController _nameController;
  String _displayName = 'Ali Khan';
  String _displayEmail = 'ali.khan@example.com';
  String _selectedAvatarUrl = '';
  
  List<dynamic> _myIncidents = [];
  bool _isLoadingHistory = true;

  @override
  void initState() {
    super.initState();
    _selectedLanguage = LanguageProvider().language;
    
    // Load local user profile data
    final profile = UserProfileHelper.cachedProfile;
    if (profile != null) {
      _displayName = profile['name'] ?? 'Ali Khan';
      _displayEmail = profile['email'] ?? 'ali.khan@example.com';
      _selectedRegion = profile['region'] ?? 'Islamabad, Capital Territory';
    }
    
    LanguageProvider().addListener(_onLanguageChanged);
    _nameController = TextEditingController(text: _displayName);
    _fetchIncidentHistory();
  }

  Future<void> _fetchIncidentHistory() async {
    final profile = UserProfileHelper.cachedProfile;
    if (profile == null) return;
    final userId = profile['user_id'];
    if (userId == null) return;

    setState(() => _isLoadingHistory = true);
    try {
      final url = '${ApiConfig.baseUrl}/incidents?user_id=$userId';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _myIncidents = data['incidents'] ?? [];
            _isLoadingHistory = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingHistory = false);
      }
    } catch (e) {
      debugPrint('Error fetching user incident history: $e');
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  @override
  void dispose() {
    LanguageProvider().removeListener(_onLanguageChanged);
    _nameController.dispose();
    super.dispose();
  }

  void _onLanguageChanged() {
    setState(() {
      _selectedLanguage = LanguageProvider().language;
    });
  }

  Widget _buildAvatarWidget() {
    if (_selectedAvatarUrl.startsWith('http')) {
      return CircleAvatar(
        radius: 50,
        backgroundColor: kPrimaryTeal.withValues(alpha: 0.15),
        child: CircleAvatar(
          radius: 46,
          backgroundImage: NetworkImage(_selectedAvatarUrl),
        ),
      );
    } else if (_selectedAvatarUrl.startsWith('agent_')) {
      Color color = kPrimaryTeal;
      IconData icon = Icons.security;
      if (_selectedAvatarUrl == 'agent_orange') {
        color = Colors.orange;
        icon = Icons.engineering;
      } else if (_selectedAvatarUrl == 'agent_red') {
        color = kEmergencyRed;
        icon = Icons.campaign;
      } else if (_selectedAvatarUrl == 'agent_green') {
        color = Colors.green;
        icon = Icons.local_activity;
      }
      return CircleAvatar(
        radius: 50,
        backgroundColor: color.withValues(alpha: 0.2),
        child: CircleAvatar(
          radius: 46,
          backgroundColor: color,
          child: Icon(icon, size: 36, color: Colors.white),
        ),
      );
    } else {
      return CircleAvatar(
        radius: 50,
        backgroundColor: kPrimaryTeal.withValues(alpha: 0.15),
        child: CircleAvatar(
          radius: 46,
          backgroundColor: Colors.grey.shade200,
          child: const Icon(Icons.person, size: 50, color: kTextLight),
        ),
      );
    }
  }

  void _openAvatarSelectionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final currentLang = LanguageProvider().language;
        final bool isUrdu = currentLang == 'اردو';

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              decoration: const BoxDecoration(
                color: kCardWhite,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  const SizedBox(height: 16),
                  Text(
                    isUrdu ? 'پروفائل تصویر منتخب کریں' : 'Choose Profile Picture',
                    style: GoogleFonts.nunito(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: kTextDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isUrdu ? 'ایک تصویر منتخب کریں جو آپ کی ہائی ڈیفینیشن پروفائل پر دکھائی دے گی' : 'Select a photo or illustrated agent badge',
                    style: GoogleFonts.nunito(fontSize: 12, color: kTextLight),
                  ),
                  const SizedBox(height: 20),

                  // ── Group A: Realistic Unsplash Photos ──
                  Text(
                    isUrdu ? 'حقیقی تصاویر' : 'Realistic Professional Photos',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: kPrimaryTeal,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 70,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _buildPhotoOption(
                          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
                          setSheetState,
                        ),
                        _buildPhotoOption(
                          'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150',
                          setSheetState,
                        ),
                        _buildPhotoOption(
                          'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150',
                          setSheetState,
                        ),
                        _buildPhotoOption(
                          'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=150',
                          setSheetState,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Group B: Illustrated Agent Badges ──
                  Text(
                    isUrdu ? 'سسٹم ایجنٹ بیجز' : 'Illustrated System Agent Badges',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: kPrimaryTeal,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildAgentOption('agent_teal', kPrimaryTeal, Icons.security, setSheetState),
                      _buildAgentOption('agent_orange', Colors.orange, Icons.engineering, setSheetState),
                      _buildAgentOption('agent_red', kEmergencyRed, Icons.campaign, setSheetState),
                      _buildAgentOption('agent_green', Colors.green, Icons.local_activity, setSheetState),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Close button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryTeal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        isUrdu ? 'منتخب کریں' : 'Confirm Choice',
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

  Widget _buildPhotoOption(String url, StateSetter setSheetState) {
    final bool isSelected = _selectedAvatarUrl == url;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedAvatarUrl = url;
        });
        setSheetState(() {});
      },
      child: Container(
        margin: const EdgeInsets.only(right: 14),
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? kPrimaryTeal : Colors.grey.shade300,
            width: isSelected ? 3 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              color: Colors.grey.shade200,
              child: const Icon(Icons.person, color: kTextLight),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAgentOption(String agentType, Color color, IconData icon, StateSetter setSheetState) {
    final bool isSelected = _selectedAvatarUrl == agentType;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedAvatarUrl = agentType;
        });
        setSheetState(() {});
      },
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.15),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: isSelected ? 3 : 0,
          ),
        ),
        child: Icon(icon, color: color, size: 26),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Text(
        title,
        style: GoogleFonts.nunito(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: kTextDark,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundLight,
      appBar: AppBar(
        title: Text(
          AppTranslations.t('profile_settings', _selectedLanguage),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: kBackgroundLight,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        children: [
          // ── Avatar + Name + Email ──
          const SizedBox(height: 8),
          Center(
            child: Stack(
              children: [
                _buildAvatarWidget(),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _openAvatarSelectionSheet,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: kPrimaryTeal,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              _displayName,
              style: GoogleFonts.nunito(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: kTextDark,
              ),
            ),
          ),
          Center(
            child: Text(
              _displayEmail,
              style: GoogleFonts.nunito(fontSize: 14, color: kTextLight),
            ),
          ),
          const SizedBox(height: 24),

          // ── 1. User Profile & Region ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Icon(Icons.person_outline, color: kPrimaryTeal, size: 20),
                const SizedBox(width: 8),
                Text(
                  AppTranslations.t('user_profile_region', _selectedLanguage),
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: kPrimaryTeal,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppTranslations.t('full_name', _selectedLanguage), style: GoogleFonts.nunito(fontSize: 13, color: kTextLight)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameController,
                  style: GoogleFonts.nunito(fontSize: 16, color: kTextDark),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: kPrimaryTeal, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(AppTranslations.t('primary_region', _selectedLanguage), style: GoogleFonts.nunito(fontSize: 13, color: kTextLight)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedRegion,
                      isExpanded: true,
                      icon: const Icon(Icons.check, color: kPrimaryTeal, size: 20),
                      items: [
                        'Islamabad, Capital Territory',
                        'Rawalpindi, Punjab',
                      ]
                          .map((region) => DropdownMenuItem(
                                value: region,
                                child: Text(
                                  region,
                                  style: GoogleFonts.nunito(fontSize: 16, color: kTextDark),
                                ),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedRegion = value);
                          LanguageProvider().setRegion(value);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(),

          // 2. Language Preferences
          _buildSectionHeader(AppTranslations.t('language_preferences', _selectedLanguage)),
          RadioListTile<String>(
            title: const Text('Urdu (اردو)'),
            value: 'اردو',
            groupValue: _selectedLanguage,
            activeColor: kPrimaryTeal,
            onChanged: (value) {
              if (value != null) {
                LanguageProvider().setLanguage(value);
              }
            },
          ),
          RadioListTile<String>(
            title: const Text('English'),
            value: 'English',
            groupValue: _selectedLanguage,
            activeColor: kPrimaryTeal,
            onChanged: (value) {
              if (value != null) {
                LanguageProvider().setLanguage(value);
              }
            },
          ),
          RadioListTile<String>(
            title: const Text('Roman Urdu'),
            value: 'Roman Urdu',
            groupValue: _selectedLanguage,
            activeColor: kPrimaryTeal,
            onChanged: (value) {
              if (value != null) {
                LanguageProvider().setLanguage(value);
              }
            },
          ),
          const Divider(),

          // 3. Notification Zones Radius
          _buildSectionHeader(AppTranslations.t('notification_radius', _selectedLanguage)),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Row(
              children: [
                Text(
                  AppTranslations.t('alert_radius', _selectedLanguage),
                  style: const TextStyle(color: kTextDark, fontSize: 16),
                ),
                Expanded(
                  child: Slider(
                    value: _alertRadius,
                    min: 1,
                    max: 10,
                    divisions: 9,
                    activeColor: kPrimaryTeal,
                    inactiveColor: Colors.teal.shade100,
                    label: '${_alertRadius.toInt()} km',
                    onChanged: (value) => setState(() => _alertRadius = value),
                  ),
                ),
                SizedBox(
                  width: 50,
                  child: Text(
                    '${_alertRadius.toInt()} km',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: kPrimaryTeal,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          const Divider(),

          // 4. Knowledge Base Connections
          _buildSectionHeader(AppTranslations.t('knowledge_base', _selectedLanguage)),
          SwitchListTile(
            title: const Text(
              'Firebase Alerts Feed',
              style: TextStyle(color: kTextDark),
            ),
            value: _firebaseAlertsEnabled,
            activeThumbColor: kPrimaryTeal,
            onChanged: (value) =>
                setState(() => _firebaseAlertsEnabled = value),
          ),
          SwitchListTile(
            title: const Text(
              'Antigravity AI Pipeline',
              style: TextStyle(color: kTextDark),
            ),
            value: _antigravityAiEnabled,
            activeThumbColor: kPrimaryTeal,
            onChanged: (value) => setState(() => _antigravityAiEnabled = value),
          ),
          const Divider(),

          // ── Save Changes Button ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
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
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryTeal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: () async {
                  setState(() {
                    _displayName = _nameController.text.trim().isNotEmpty
                        ? _nameController.text.trim()
                        : 'Ali Khan';
                  });

                  // Save updated profile locally
                  final currentProfile = UserProfileHelper.cachedProfile;
                  if (currentProfile != null) {
                    final updated = {
                      'user_id': currentProfile['user_id'] ?? 'USR-UNKNOWN',
                      'email': currentProfile['email'] ?? 'ali.khan@example.com',
                      'name': _displayName,
                      'region': _selectedRegion,
                    };
                    await UserProfileHelper.saveProfile(updated);
                  }
                  
                  if (!context.mounted) return;

                  // Show animated dynamic confirmation dialog
                  showDialog(
                    context: context,
                    builder: (context) {
                      final currentLang = LanguageProvider().language;
                      final bool isUrdu = currentLang == 'اردو';
                      
                      return Dialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFFE0F2F1),
                                ),
                                child: const Icon(
                                  Icons.check_circle_outline,
                                  color: kPrimaryTeal,
                                  size: 36,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                isUrdu ? 'پروفائل اپ ڈیٹ ہو گئی!' : 'Profile Synchronized!',
                                style: GoogleFonts.nunito(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: kTextDark,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                isUrdu 
                                    ? 'آپ کی معلومات اور ترجیحات کو کامیابی کے ساتھ سسٹم میں محفوظ کر لیا گیا ہے۔'
                                    : 'Your updated credentials, active region, and image preferences are successfully secured.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.nunito(
                                  fontSize: 12,
                                  color: kTextLight,
                                ),
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                height: 44,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: kPrimaryTeal,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: () => Navigator.pop(context),
                                  child: Text(isUrdu ? 'ٹھیک ہے' : 'Dismiss'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
                child: Text(
                  _selectedLanguage == 'اردو' ? 'معلومات محفوظ کریں' : 'Save Changes',
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
          ),
        ),

        // ── My Incident History Section ──
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            children: [
              const Icon(Icons.history, color: kPrimaryTeal, size: 20),
              const SizedBox(width: 8),
              Text(
                _selectedLanguage == 'اردو' ? 'میری رپورٹ کردہ ہسٹری' : 'MY REPORT HISTORY',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: kPrimaryTeal,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
        
        if (_isLoadingHistory)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: CircularProgressIndicator(color: kPrimaryTeal),
            ),
          )
        else if (_myIncidents.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                _selectedLanguage == 'اردو' 
                    ? 'آپ نے ابھی تک کوئی رپورٹ جمع نہیں کروائی ہے۔'
                    : 'You have not submitted any incident reports yet.',
                style: GoogleFonts.nunito(color: kTextLight, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _myIncidents.length,
            itemBuilder: (context, index) {
              final incident = _myIncidents[index];
              final type = incident['incident_type'] ?? 'Emergency';
              final status = incident['status'] ?? 'PROCESSING';
              final priority = incident['priority'] ?? 'P5';
              final id = incident['incident_id'] ?? incident['id'] ?? 'SIG-...';
              
              Color statusColor = Colors.orange;
              if (status == 'RESOLVED') {
                statusColor = Colors.green;
              }
              if (status == 'ASSIGNED') {
                statusColor = Colors.blue;
              }

              Color priorityColor = Colors.grey;
              if (priority == 'P1') {
                priorityColor = kEmergencyRed;
              } else if (priority == 'P2') {
                priorityColor = Colors.orange;
              } else if (priority == 'P3') {
                priorityColor = Colors.amber;
              }

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => IncidentTrackerScreen(incidentData: incident),
                      ),
                    );
                  },
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: priorityColor.withValues(alpha: 0.1),
                    child: Icon(
                      type.toString().toLowerCase().contains('fire')
                          ? Icons.local_fire_department
                          : type.toString().toLowerCase().contains('flood')
                              ? Icons.water_damage
                              : Icons.warning_amber_rounded,
                      color: priorityColor,
                    ),
                  ),
                  title: Text(
                    'Case: $type',
                    style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 15, color: kTextDark),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        'ID: $id',
                        style: GoogleFonts.nunito(fontSize: 12, color: kTextLight),
                      ),
                    ],
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status,
                      style: GoogleFonts.nunito(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        const Divider(),

        // Sign Out Button
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: OutlinedButton(
              onPressed: () async {
                final navigator = Navigator.of(context);
                await UserProfileHelper.clearProfile();
                navigator.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const AuthScreen()),
                  (route) => false,
                );
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.grey),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                AppTranslations.t('sign_out', _selectedLanguage),
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}
