import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:tsbd_app/screens/splash.dart';
import 'package:tsbd_app/screens/maintenance_mode.dart';
import 'package:tsbd_app/utils/app_config.dart';
import 'package:tsbd_app/services/ad_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:tsbd_app/services/app_localizations.dart';
import 'package:tsbd_app/services/language_service.dart';
import 'screens/admin_panel.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize AdMob
  await MobileAds.instance.initialize();

  // Initialize OneSignal
  OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
  OneSignal.initialize('d251bf76-084a-4616-a1a7-d482a823474b');

  // Enable in-app messaging
  OneSignal.InAppMessages.paused(false);

  // Request push notification permission
  OneSignal.Notifications.requestPermission(true);

  // Set notification opened handler
  OneSignal.Notifications.addClickListener((event) {
    debugPrint('Notification clicked: ${event.notification.additionalData}');
  });

  // Set in-app message clicked handler
  OneSignal.InAppMessages.addClickListener((event) {
    debugPrint('In-app message clicked: ${event.result.actionId}');
  });

  // Set in-app message will display handler
  OneSignal.InAppMessages.addWillDisplayListener((event) {
    debugPrint('In-app message will display: ${event.message.messageId}');
  });

  // Initialize Firebase
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'AIzaSyCmjatCkTvoBEa0AYdpQN27eK_tpAt6NPA',
      authDomain: 'tsbd-store.firebaseapp.com',
      projectId: 'tsbd-store',
      storageBucket: 'tsbd-store.firebasestorage.app',
      messagingSenderId: '293032778739',
      appId: '1:293032778739:web:f985d0a3dfaf8a880b9086',
      databaseURL: 'https://tsbd-store-default-rtdb.firebaseio.com',
    ),
  );

  // Initialize AppConfig and check maintenance mode
  await AppConfig.initialize();
  final isMaintenanceMode = await AppConfig.checkMaintenanceMode();
  debugPrint('Initial maintenance mode state: $isMaintenanceMode');

  // Initialize AdService
  final adService = AdService();
  await adService.initialize();

  // Get initial locale based on saved language preference
  final locale = await LanguageService.getCurrentLocale();

  runApp(MyApp(isMaintenanceMode: isMaintenanceMode, initialLocale: locale));
}

class MyApp extends StatefulWidget {
  final bool isMaintenanceMode;
  final Locale initialLocale;

  const MyApp({
    super.key,
    required this.isMaintenanceMode,
    required this.initialLocale,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isDarkMode = false;
  bool _maintenanceMode = false;
  late Locale _currentLocale;

  @override
  void initState() {
    super.initState();
    _currentLocale = widget.initialLocale;
    _loadTheme();
    _setupMaintenanceMode();
  }

  @override
  void dispose() {
    AppConfig.dispose();
    super.dispose();
  }

  void _setupMaintenanceMode() {
    debugPrint('Setting up maintenance mode listener in MyApp...');
    AppConfig.getMaintenanceModeStream().listen(
      (isMaintenanceMode) {
        debugPrint('Maintenance mode state changed to: $isMaintenanceMode');
        setState(() {
          _maintenanceMode = isMaintenanceMode;
        });
      },
      onError: (error) {
        debugPrint('Error in maintenance mode stream: $error');
        setState(() {
          _maintenanceMode = false;
        });
      },
    );
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('darkMode') ?? false;
    });
  }

  void _handleDarkModeChanged(bool value) {
    setState(() {
      _isDarkMode = value;
    });
  }

  void _handleLanguageChanged(String language) async {
    final locale = LanguageService.getLocaleFromLanguage(language);
    await LanguageService.setLanguage(language);

    setState(() {
      _currentLocale = locale;
    });
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('MyApp build called, maintenance mode: $_maintenanceMode');
    debugPrint('Current locale: ${_currentLocale.languageCode}');

    return MaterialApp(
      title: 'TSBD App Store',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: _isDarkMode ? Brightness.dark : Brightness.light,
        ),
        useMaterial3: true,
      ),
      locale: _currentLocale,
      supportedLocales: const [
        Locale('en', ''), // English
        Locale('bn', ''), // Bangla
      ],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home:
          _maintenanceMode
              ? const MaintenanceModeScreen()
              : SplashScreen(
                onDarkModeChanged: _handleDarkModeChanged,
                onLanguageChanged: _handleLanguageChanged,
              ),
    );
  }
}
