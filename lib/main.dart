import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme/app_theme.dart';
import 'services/storage_service.dart';
import 'providers/sleep_provider.dart';
import 'providers/audio_provider.dart';
import 'providers/sleep_audio_provider.dart';
import 'screens/navigation/main_navigation_screen.dart';
import 'screens/onboarding/disclaimer_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final storageService = StorageService(prefs);
  final bool hasAcceptedDisclaimer = prefs.getBool('has_accepted_disclaimer') ?? false;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SleepProvider(storageService)),
        ChangeNotifierProvider(create: (_) => AudioProvider()),
        ChangeNotifierProvider(create: (_) => SleepAudioProvider()),
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
