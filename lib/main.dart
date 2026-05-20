// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:khabar/screens/alerts_screen.dart';
import 'package:khabar/screens/home_screen.dart';
import 'package:khabar/screens/map_screen.dart';
import 'package:khabar/screens/profile_screen.dart';
import 'package:khabar/screens/quick_report_bottom_sheet.dart';
import 'package:khabar/screens/splash_screen.dart';
import 'package:khabar/theme/app_colors.dart';
import 'package:khabar/theme/language_provider.dart';
import 'package:khabar/theme/translations.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// Global navigator key to allow dialogs and routing from FCM callbacks
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('[FCM] Background message: ${message.notification?.title}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (requires google-services.json in android/app/)
  try {
    await Firebase.initializeApp();

    // Register background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Subscribe to the KHABAR public alerts topic
    await FirebaseMessaging.instance.subscribeToTopic('khabar_public_alerts');
    debugPrint('[FCM] ✅ Subscribed to khabar_public_alerts topic');

    // Request iOS/Android 13+ notification permission
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('[FCM] Foreground message: ${message.notification?.title}');
      if (message.notification != null && navigatorKey.currentContext != null) {
        final context = navigatorKey.currentContext!;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message.notification?.title ?? 'Critical Alert',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: Text(
              message.notification?.body ?? '',
              style: const TextStyle(fontSize: 15),
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Dismiss', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kEmergencyRed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const AlertsScreen()));
                },
                child: const Text('View Source'),
              ),
            ],
          ),
        );
      }
    });

    // Handle background notification clicks
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[FCM] Notification clicked! Routing to source page.');
      if (navigatorKey.currentContext != null) {
        Navigator.push(
          navigatorKey.currentContext!,
          MaterialPageRoute(builder: (context) => const AlertsScreen()),
        );
      }
    });
  } catch (e) {
    // Firebase not configured yet — app runs without push notifications
    debugPrint('[FCM] Firebase not initialized (add google-services.json): $e');
  }

  runApp(const KhabarApp());
}


class KhabarApp extends StatelessWidget {
  const KhabarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Khabar App',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''), // English
        Locale('ur', ''), // Urdu
      ],
      builder: (context, child) {
        // Global Responsive Logic:
        // Automatically scales all text based on screen width relative to a 390px baseline (iPhone 14)
        // Clamped between 0.85 and 1.3 to prevent extreme distortions on tiny or huge screens.
        final mediaQuery = MediaQuery.of(context);
        final double scaleFactor = (mediaQuery.size.width / 390.0).clamp(0.85, 1.3);

        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: TextScaler.linear(scaleFactor),
          ),
          child: child!,
        );
      },
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: kPrimaryTeal,
        scaffoldBackgroundColor: kBackgroundLight,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kPrimaryTeal,
          primary: kPrimaryTeal,
          error: kEmergencyRed,
          surface: kBackgroundLight,
        ),
        textTheme: GoogleFonts.nunitoTextTheme(Theme.of(context).textTheme),
        cardTheme: CardThemeData(
          color: kCardWhite,
          surfaceTintColor: Colors.transparent,
          elevation: 2,
          shadowColor: Colors.black.withValues(alpha: 0.15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: kCardWhite,
          selectedItemColor: kPrimaryTeal,
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    MapScreen(),
    SizedBox.shrink(), // Placeholder for index 2 which is intercepted by bottom sheet
    AlertsScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    LanguageProvider().addListener(_onLanguageChanged);
  }

  @override
  void dispose() {
    LanguageProvider().removeListener(_onLanguageChanged);
    super.dispose();
  }

  void _onLanguageChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            if (index == 2) {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => const QuickReportBottomSheet(),
              );
            } else {
              setState(() {
                _currentIndex = index;
              });
            }
          },
          showSelectedLabels: true,
          showUnselectedLabels: true,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.normal,
            fontSize: 12,
          ),
          items: [
            _buildNavItem(Icons.home_outlined, Icons.home, AppTranslations.t('home_tab', LanguageProvider().language), 0),
            _buildNavItem(Icons.map_outlined, Icons.map, AppTranslations.t('maps_tab', LanguageProvider().language), 1),
            _buildNavItem(
              Icons.add_circle_outline,
              Icons.add_circle,
              AppTranslations.t('report_tab', LanguageProvider().language),
              2,
            ),
            _buildNavItem(
              Icons.notifications_none_outlined,
              Icons.notifications,
              AppTranslations.t('alerts', LanguageProvider().language),
              3,
            ),
            _buildNavItem(Icons.person_outline, Icons.person, AppTranslations.t('profile_tab', LanguageProvider().language), 4),
          ],
        ),
      ),
    );
  }

  BottomNavigationBarItem _buildNavItem(
    IconData iconData,
    IconData activeIconData,
    String label,
    int index,
  ) {
    bool isSelected = _currentIndex == index;
    return BottomNavigationBarItem(
      icon: isSelected
          ? Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: kPrimaryTeal,
                shape: BoxShape.circle,
              ),
              child: Icon(activeIconData, color: Colors.white, size: 24),
            )
          : Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(iconData, size: 24),
            ),
      label: label,
    );
  }
}


