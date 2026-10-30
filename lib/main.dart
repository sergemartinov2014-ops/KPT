import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme/app_theme.dart';
import 'services/storage_service.dart';
import 'providers/sleep_provider.dart';
import 'providers/audio_provider.dart';
import 'providers/sleep_audio_provider.dart';
import 'providers/smart_alarm_provider.dart';
import 'screens/navigation/main_navigation_screen.dart';
import 'screens/onboarding/disclaimer_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final storageService = StorageService(prefs);
  final bool hasAcceptedDisclaimer =
      kIsWeb ? true : (prefs.getBool('has_accepted_disclaimer') ?? false);

  final sleepAudioProvider = SleepAudioProvider();
  final smartAlarmProvider = SmartAlarmProvider(
    sleepRecorderService: sleepAudioProvider.service,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SleepProvider(storageService)),
        ChangeNotifierProvider(create: (_) => AudioProvider()),
        ChangeNotifierProvider.value(value: sleepAudioProvider),
        ChangeNotifierProvider.value(value: smartAlarmProvider),
      ],
      child: SomniaApp(initialRouteIsDisclaimer: !hasAcceptedDisclaimer),
    ),
  );
}

class SomniaApp extends StatelessWidget {
  final bool initialRouteIsDisclaimer;

  const SomniaApp({
    super.key,
    required this.initialRouteIsDisclaimer,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Сомния',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        final isDesktop = mediaQuery.size.width > 560;

        if (!isDesktop) return child!;

        const double frameWidth = 460.0;
        final frameHeight = mediaQuery.size.height > 880
            ? 840.0
            : mediaQuery.size.height * 0.96;
        return Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.2,
              colors: [
                Color(0xFF0F172A),
                Color(0xFF020408),
              ],
            ),
          ),
          child: Center(
            child: Container(
              width: frameWidth,
              height: frameHeight,
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(44),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.18),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.20),
                    blurRadius: 50,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.8),
                    blurRadius: 40,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(42),
                child: MediaQuery(
                  data: mediaQuery.copyWith(
                    size: Size(frameWidth, frameHeight),
                  ),
                  child: child!,
                ),
              ),
            ),
          ),
        );
      },
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ru', 'RU'),
        Locale('en', 'US'),
      ],
      locale: const Locale('ru', 'RU'),
      home: initialRouteIsDisclaimer
          ? const DisclaimerScreen()
          : const MainNavigationScreen(),
    );
  }
}
