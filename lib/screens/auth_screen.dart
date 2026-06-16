import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:khabar/api_config.dart';
import 'package:khabar/main.dart';
import 'package:khabar/theme/app_colors.dart';
import 'package:khabar/theme/language_provider.dart';
import 'package:khabar/theme/translations.dart';
import 'package:khabar/utils/user_profile_helper.dart';
import 'package:khabar/screens/offline_chat_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _loginFormKey = GlobalKey<FormState>();
  final _signupFormKey = GlobalKey<FormState>();

  // Input Controllers
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  
  final _signupEmailController = TextEditingController();
  final _signupPasswordController = TextEditingController();
  final _signupConfirmPasswordController = TextEditingController();
  final _signupNameController = TextEditingController();
  
  String _selectedRegion = 'Islamabad, Capital Territory';
  bool _obscureLoginPassword = true;
  bool _obscureSignupPassword = true;
  bool _obscureSignupConfirmPassword = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
    LanguageProvider().addListener(_onLanguageChanged);
  }

  @override
  void dispose() {
    LanguageProvider().removeListener(_onLanguageChanged);
    _tabController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _signupEmailController.dispose();
    _signupPasswordController.dispose();
    _signupConfirmPasswordController.dispose();
    _signupNameController.dispose();
    super.dispose();
  }

  void _onLanguageChanged() {
    setState(() {});
  }

  Future<void> _handleLogin() async {
    if (!_loginFormKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _loginEmailController.text.trim(),
          'password': _loginPasswordController.text,
        }),
      ).timeout(const Duration(seconds: 8));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final user = data['user'] as Map<String, dynamic>;
        await UserProfileHelper.saveProfile(user);
        LanguageProvider().setRegion(user['region'] ?? 'Islamabad, Capital Territory');
        
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const MainScreen()),
          );
        }
      } else {
        _showErrorSnackBar(data['detail'] ?? 'Login failed. Please check credentials.');
      }
    } catch (e) {
      _showErrorSnackBar('Network error. Is the backend server running?');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSignup() async {
    if (!_signupFormKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _signupEmailController.text.trim(),
          'password': _signupPasswordController.text,
          'name': _signupNameController.text.trim(),
          'region': _selectedRegion,
        }),
      ).timeout(const Duration(seconds: 8));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final user = data['user'] as Map<String, dynamic>;
        await UserProfileHelper.saveProfile(user);
        LanguageProvider().setRegion(user['region'] ?? 'Islamabad, Capital Territory');
        
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const MainScreen()),
          );
        }
      } else {
        _showErrorSnackBar(data['detail'] ?? 'Registration failed.');
      }
    } catch (e) {
      _showErrorSnackBar('Network error. Is the backend server running?');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.nunito(fontWeight: FontWeight.bold),
        ),
        backgroundColor: kEmergencyRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageProvider().language;
    final isUrdu = lang == 'اردو';

    return Scaffold(
      backgroundColor: const Color(0xFF071413),
      body: Stack(
        children: [
          // Background Gradient and ambient glow elements
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0C2724),
                    Color(0xFF050E0D),
                  ],
                ),
              ),
            ),
          ),
          
          // Glow Circle Top-Left
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF14C3B4).withValues(alpha: 0.06),
              ),
            ),
          ),
          
          // Glow Circle Bottom-Right
          Positioned(
            bottom: -80,
            right: -80,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1E827B).withValues(alpha: 0.05),
              ),
            ),
          ),

          // Language Switcher Top Right
          Positioned(
            top: 40,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: lang,
                  dropdownColor: const Color(0xFF0B1E1C),
                  style: GoogleFonts.nunito(
                    color: Colors.white, 
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  icon: const Padding(
                    padding: EdgeInsets.only(left: 4.0),
                    child: Icon(Icons.language, color: Color(0xFF14C3B4), size: 16),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'English', child: Text('EN')),
                    DropdownMenuItem(value: 'اردو', child: Text('اردو')),
                    DropdownMenuItem(value: 'Roman Urdu', child: Text('ROM')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      LanguageProvider().setLanguage(val);
                    }
                  },
                ),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Header Logo & Branding with Radial Glow
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF14C3B4).withValues(alpha: 0.05),
                      ),
                      constraints: const BoxConstraints(maxWidth: 120, maxHeight: 120),
                      child: Image.asset(
                        'assets/Khabar Logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'KHABAR',
                      style: GoogleFonts.nunito(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 3.0,
                        shadows: [
                          Shadow(
                            color: const Color(0xFF14C3B4).withValues(alpha: 0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isUrdu
                          ? 'بحران انٹیلی جنس رسپانس پلیٹ فارم'
                          : 'Crisis Intelligence Platform',
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.teal.shade200,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Main Auth Card (Glassmorphic Container)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xDF0A1D1C),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.4),
                                blurRadius: 24,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Tab selector
                                Container(
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.35),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                                  ),
                                  child: TabBar(
                                    controller: _tabController,
                                    indicatorSize: TabBarIndicatorSize.tab,
                                    dividerColor: Colors.transparent,
                                    indicatorPadding: EdgeInsets.zero,
                                    indicator: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF1E827B),
                                          Color(0xFF12524E),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF1E827B).withValues(alpha: 0.35),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    labelColor: Colors.white,
                                    unselectedLabelColor: Colors.white.withValues(alpha: 0.5),
                                    labelStyle: GoogleFonts.nunito(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                    tabs: [
                                      Tab(text: AppTranslations.t('login', lang)),
                                      Tab(text: AppTranslations.t('signup', lang)),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // Dynamic Height Form Wrapper
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                  height: _tabController.index == 0 ? 270 : 495,
                                  child: TabBarView(
                                    controller: _tabController,
                                    children: [
                                      _buildLoginForm(lang),
                                      _buildSignupForm(lang),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildOfflineButton(isUrdu, lang),
                  ],
                ),
              ),
            ),
          ),
          
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.6),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF14C3B4),
                    strokeWidth: 3,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoginForm(String lang) {
    return Form(
      key: _loginFormKey,
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 4),
          _buildTextField(
            controller: _loginEmailController,
            label: AppTranslations.t('email', lang),
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.isEmpty || !value.contains('@')) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _loginPasswordController,
            label: AppTranslations.t('password', lang),
            icon: Icons.lock_outline,
            obscureText: _obscureLoginPassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureLoginPassword ? Icons.visibility : Icons.visibility_off, 
                color: Colors.white.withValues(alpha: 0.4), 
                size: 20,
              ),
              onPressed: () => setState(() => _obscureLoginPassword = !_obscureLoginPassword),
            ),
            validator: (value) {
              if (value == null || value.isEmpty || value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 36),
          Container(
            height: 52,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF2EA39B),
                  Color(0xFF165E59),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2EA39B).withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _handleLogin,
              child: Text(
                AppTranslations.t('login', lang),
                style: GoogleFonts.nunito(
                  fontSize: 16, 
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignupForm(String lang) {
    return Form(
      key: _signupFormKey,
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        physics: const BouncingScrollPhysics(),
        children: [
          const SizedBox(height: 4),
          _buildTextField(
            controller: _signupNameController,
            label: AppTranslations.t('full_name', lang),
            icon: Icons.person_outline,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your name';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _signupEmailController,
            label: AppTranslations.t('email', lang),
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.isEmpty || !value.contains('@')) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          // Region Selector Dropdown matching the Dark Glass Theme
          DropdownButtonFormField<String>(
            initialValue: _selectedRegion,
            style: GoogleFonts.nunito(color: Colors.white, fontSize: 15),
            dropdownColor: const Color(0xFF0B1E1C),
            icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF14C3B4)),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.map_outlined, color: Color(0xFF14C3B4), size: 20),
              labelText: AppTranslations.t('primary_region', lang),
              labelStyle: GoogleFonts.nunito(color: Colors.white.withValues(alpha: 0.5)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              filled: true,
              fillColor: Colors.black.withValues(alpha: 0.25),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF14C3B4), width: 1.5),
              ),
            ),
            items: [
              DropdownMenuItem(
                value: 'Islamabad, Capital Territory', 
                child: Text('Islamabad', style: GoogleFonts.nunito(color: Colors.white)),
              ),
              DropdownMenuItem(
                value: 'Rawalpindi, Punjab', 
                child: Text('Rawalpindi', style: GoogleFonts.nunito(color: Colors.white)),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedRegion = value);
              }
            },
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _signupPasswordController,
            label: AppTranslations.t('password', lang),
            icon: Icons.lock_outline,
            obscureText: _obscureSignupPassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureSignupPassword ? Icons.visibility : Icons.visibility_off, 
                color: Colors.white.withValues(alpha: 0.4), 
                size: 20,
              ),
              onPressed: () => setState(() => _obscureSignupPassword = !_obscureSignupPassword),
            ),
            validator: (value) {
              if (value == null || value.isEmpty || value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _signupConfirmPasswordController,
            label: AppTranslations.t('confirm_password', lang),
            icon: Icons.lock_outline,
            obscureText: _obscureSignupConfirmPassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureSignupConfirmPassword ? Icons.visibility : Icons.visibility_off, 
                color: Colors.white.withValues(alpha: 0.4), 
                size: 20,
              ),
              onPressed: () => setState(() => _obscureSignupConfirmPassword = !_obscureSignupConfirmPassword),
            ),
            validator: (value) {
              if (value != _signupPasswordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          Container(
            height: 52,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF2EA39B),
                  Color(0xFF165E59),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2EA39B).withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _handleSignup,
              child: Text(
                AppTranslations.t('signup', lang),
                style: GoogleFonts.nunito(
                  fontSize: 16, 
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: GoogleFonts.nunito(color: Colors.white, fontSize: 15),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.nunito(color: Colors.white.withValues(alpha: 0.5)),
        prefixIcon: Icon(icon, color: const Color(0xFF14C3B4), size: 20),
        suffixIcon: suffixIcon,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.25),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF14C3B4), width: 1.5),
        ),
        errorStyle: GoogleFonts.nunito(color: const Color(0xFFFF6B6B), fontSize: 11),
      ),
    );
  }

  Widget _buildOfflineButton(bool isUrdu, String lang) {
    String label = "Offline AI Assistant (No Internet)";
    if (lang == 'اردو') {
      label = "آف لائن اے آئی اسسٹنٹ (بغیر انٹرنیٹ)";
    } else if (lang == 'Roman Urdu') {
      label = "Offline AI Assistant (Bina Internet)";
    }
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          width: double.infinity,
          height: 54,
          decoration: BoxDecoration(
            color: const Color(0x7F0A1D1C),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF14C3B4).withValues(alpha: 0.3),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF14C3B4).withValues(alpha: 0.1),
                blurRadius: 8,
                spreadRadius: 1,
              )
            ]
          ),
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const OfflineChatScreen(),
                ),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.wifi_off_rounded,
                  color: Color(0xFF14C3B4),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: GoogleFonts.nunito(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
