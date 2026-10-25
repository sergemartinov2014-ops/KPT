import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sleep_diary_entry.dart';
import '../models/sleep_window.dart';

class StorageService {
  static const String _keyDiaryEntries = 'somnia_diary_entries';
  static const String _keySleepWindow = 'somnia_sleep_window';
  static const String _keyIsiHistory = 'somnia_isi_history';
  static const String _keySafeModeSRT = 'somnia_is_safe_mode_srt';

  final SharedPreferences _prefs;

  StorageService(this._prefs);

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
  }

  // --- Дневник сна ---

  static String clinicalDateKey(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  List<SleepDiaryEntry> loadDiaryEntries() {
    final List<String>? jsonList = _prefs.getStringList(_keyDiaryEntries);
    if (jsonList == null) return [];
    return jsonList.map((str) => SleepDiaryEntry.fromJson(json.decode(str))).toList()
      ..sort((a, b) => b.date.compareTo(a.date)); // От новых к старым
  }

  /// Сохранение с гарантированной дедупликацией по клинической дате пробуждения (YYYY-MM-DD)
  Future<void> saveDiaryEntry(SleepDiaryEntry entry) async {
    final entries = loadDiaryEntries();
    final targetKey = clinicalDateKey(entry.date);
    // Удаляем предыдущую запись за эту же ночь, если она уже была
    entries.removeWhere((e) => clinicalDateKey(e.date) == targetKey);
    entries.add(entry);

    final jsonList = entries.map((e) => json.encode(e.toJson())).toList();
    await _prefs.setStringList(_keyDiaryEntries, jsonList);
  }

  Future<void> deleteDiaryEntry(String id) async {
    final entries = loadDiaryEntries();
    entries.removeWhere((e) => e.id == id);
    final jsonList = entries.map((e) => json.encode(e.toJson())).toList();
    await _prefs.setStringList(_keyDiaryEntries, jsonList);
  }

  // --- Окно сна ---

  SleepWindow loadSleepWindow() {
    final String? str = _prefs.getString(_keySleepWindow);
    if (str == null) return SleepWindow.defaultWindow();
    try {
      return SleepWindow.fromJson(json.decode(str));
    } catch (_) {
      return SleepWindow.defaultWindow();
    }
  }

  Future<void> saveSleepWindow(SleepWindow window) async {
    await _prefs.setString(_keySleepWindow, json.encode(window.toJson()));
  }

  // --- Безопасный режим титрации (Safe-SRT Mode) ---

  bool get isSafeModeSRT => _prefs.getBool(_keySafeModeSRT) ?? false;

  Future<void> setSafeModeSRT(bool val) async {
    await _prefs.setBool(_keySafeModeSRT, val);
  }

  // --- История тестов ISI ---

  List<Map<String, dynamic>> loadIsiHistory() {
    final List<String>? jsonList = _prefs.getStringList(_keyIsiHistory);
    if (jsonList == null) return [];
    return jsonList.map((str) => Map<String, dynamic>.from(json.decode(str))).toList();
  }

  Future<void> saveIsiResult(int score, String title, DateTime date) async {
    final history = loadIsiHistory();
    history.add({
      'score': score,
      'title': title,
      'date': date.toIso8601String(),
    });
    final jsonList = history.map((e) => json.encode(e)).toList();
    await _prefs.setStringList(_keyIsiHistory, jsonList);
  }

  /// Полное удаление всех данных пользователя (GDPR / 152-ФЗ)
  Future<void> clearAllData() async {
    await _prefs.remove(_keyDiaryEntries);
    await _prefs.remove(_keySleepWindow);
    await _prefs.remove(_keyIsiHistory);
    await _prefs.remove(_keySafeModeSRT);
  }
}
