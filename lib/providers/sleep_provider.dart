import 'package:flutter/foundation.dart';
import '../models/sleep_diary_entry.dart';
import '../models/sleep_window.dart';
import '../services/storage_service.dart';
import '../services/sleep_calculator.dart';

class SleepProvider extends ChangeNotifier {
  final StorageService _storage;

  List<SleepDiaryEntry> _entries = [];
  SleepWindow _window = SleepWindow.defaultWindow();
  TitrationResult? _latestTitration;

  SleepProvider(this._storage) {
    _loadData();
  }

  List<SleepDiaryEntry> get entries => _entries;
  SleepWindow get currentWindow => _window;
  TitrationResult? get latestTitration => _latestTitration;

  void _loadData() {
    _entries = _storage.loadDiaryEntries();
    _window = _storage.loadSleepWindow();
    _recalculateTitration();
    notifyListeners();
  }

  bool get hasTodayEntry {
    final now = DateTime.now();
    return _entries.any((e) =>
        e.date.year == now.year &&
        e.date.month == now.month &&
        e.date.day == now.day);
  }

  SleepDiaryEntry? get todayEntry {
    final now = DateTime.now();
    try {
      return _entries.firstWhere((e) =>
          e.date.year == now.year &&
          e.date.month == now.month &&
          e.date.day == now.day);
    } catch (_) {
      return null;
    }
  }

  double get averageWeeklySE {
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    final valid = _entries.where((e) => e.date.isAfter(sevenDaysAgo)).toList();
    if (valid.isEmpty) return 0.0;
    final sum = valid.fold<double>(0.0, (acc, e) => acc + e.sleepEfficiency);
    return sum / valid.length;
  }

  int get averageWeeklyTSTMinutes {
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    final valid = _entries.where((e) => e.date.isAfter(sevenDaysAgo)).toList();
    if (valid.isEmpty) return 0;
    final sum = valid.fold<int>(0, (acc, e) => acc + e.totalSleepTimeMinutes);
    return sum ~/ valid.length;
  }

  Future<void> addDiaryEntry(SleepDiaryEntry entry) async {
    await _storage.saveDiaryEntry(entry);
    _entries = _storage.loadDiaryEntries();
    _recalculateTitration();
    notifyListeners();
  }

  Future<void> deleteDiaryEntry(String id) async {
    await _storage.deleteDiaryEntry(id);
    _entries = _storage.loadDiaryEntries();
    _recalculateTitration();
    notifyListeners();
  }

  bool get isSafeModeSRT => _storage.isSafeModeSRT;

  Future<void> toggleSafeModeSRT(bool val) async {
    await _storage.setSafeModeSRT(val);
    _recalculateTitration();
    notifyListeners();
  }

  void _recalculateTitration() {
    _latestTitration = SleepCalculator.evaluateWeeklyTitration(
      recentEntries: _entries,
      currentWindow: _window,
      isSafeModeSRT: _storage.isSafeModeSRT,
    );
  }

  Future<void> applyTitrationRecommendation() async {
    if (_latestTitration?.recommendedWindow != null) {
      _window = _latestTitration!.recommendedWindow!;
      await _storage.saveSleepWindow(_window);
      _recalculateTitration();
      notifyListeners();
    }
  }

  Future<bool> updateCustomWindow(int bedHour, int bedMinute, int wakeHour, int wakeMinute) async {
    final candidate = SleepWindow(
      bedHour: bedHour,
      bedMinute: bedMinute,
      wakeHour: wakeHour,
      wakeMinute: wakeMinute,
      lastUpdated: DateTime.now(),
      isActive: true,
    );
    final minFloor = _storage.isSafeModeSRT
        ? SleepCalculator.minSafetyWindowMinutesSafeMode
        : SleepCalculator.minSafetyWindowMinutesStandard;

    if (candidate.windowDurationMinutes < minFloor) {
      return false; // Блокируем опасное сужение окна вручную
    }
    _window = candidate;
    await _storage.saveSleepWindow(_window);
    _recalculateTitration();
    notifyListeners();
    return true;
  }

  List<Map<String, dynamic>> get isiHistory => _storage.loadIsiHistory();

  Future<void> saveIsiResult(int score, String title) async {
    await _storage.saveIsiResult(score, title, DateTime.now());
    notifyListeners();
  }

  Future<void> clearAllData() async {
    await _storage.clearAllData();
    _loadData();
    notifyListeners();
  }
}
