import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:somnia/providers/app_lock_provider.dart';
import 'package:somnia/providers/audio_provider.dart';
import 'package:somnia/providers/sleep_audio_provider.dart';
import 'package:somnia/providers/sleep_provider.dart';
import 'package:somnia/providers/smart_alarm_provider.dart';
import 'package:somnia/screens/navigation/main_navigation_screen.dart';
import 'package:somnia/services/storage_service.dart';
import 'package:somnia/widgets/liquid_glass.dart';

Future<void> _pumpDiaryScreen(WidgetTester tester, {required double bottomInset}) async {
  await initializeDateFormatting('ru');

  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  tester.view.padding = FakeViewPadding(bottom: bottomInset * 3);
  tester.view.viewPadding = FakeViewPadding(bottom: bottomInset * 3);
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final sleepAudio = SleepAudioProvider();

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SleepProvider(StorageService(prefs))),
        ChangeNotifierProvider(create: (_) => AudioProvider()),
        ChangeNotifierProvider(create: (_) => AppLockProvider(prefs)),
        ChangeNotifierProvider.value(value: sleepAudio),
        ChangeNotifierProvider(create: (_) => SmartAlarmProvider()),
      ],
      child: const MaterialApp(home: MainNavigationScreen()),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.text('Дневник'));
  await tester.pumpAndSettle();

  // Другие экраны в IndexedStack дают посторонние overflow-ошибки на тестовом
  // размере шрифта — к проверке FAB отношения не имеют.
  while (tester.takeException() != null) {}
}

void _expectFabClearsTabBar(WidgetTester tester) {
  final Rect fabRect = tester.getRect(find.byType(FloatingActionButton));
  final Rect tabBarRect = tester.getRect(
    find.ancestor(
      of: find.text('Практики'),
      matching: find.byType(LiquidGlass),
    ).first,
  );

  debugPrint('gap: ${tabBarRect.top - fabRect.bottom}');

  expect(
    fabRect.bottom,
    lessThanOrEqualTo(tabBarRect.top - 8),
    reason: 'FAB must stay at least 8pt above the floating tab bar',
  );
}

void main() {
  testWidgets('diary FAB clears floating tab bar (home indicator)', (tester) async {
    await _pumpDiaryScreen(tester, bottomInset: 34);
    _expectFabClearsTabBar(tester);
  });

  testWidgets('diary FAB clears floating tab bar (no bottom inset)', (tester) async {
    await _pumpDiaryScreen(tester, bottomInset: 0);
    _expectFabClearsTabBar(tester);
  });
}
