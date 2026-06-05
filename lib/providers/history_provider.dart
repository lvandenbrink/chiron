import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/workout_log.dart';

class HistoryProvider extends ChangeNotifier {
  static const _key = 'workout_history';
  List<WorkoutLog> _logs = [];

  List<WorkoutLog> get logs => List.unmodifiable(_logs);

  bool hasWorkoutOnDate(DateTime date) =>
      _logs.any((l) => _sameDay(l.date, date));

  List<WorkoutLog> logsForDate(DateTime date) =>
      _logs.where((l) => _sameDay(l.date, date)).toList();

  List<WorkoutLog> logsForMonth(int year, int month) => _logs
      .where((l) => l.date.year == year && l.date.month == month)
      .toList();

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    final list = jsonDecode(raw) as List;
    _logs = list
        .map((e) => WorkoutLog.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    notifyListeners();
  }

  Future<void> addLog(WorkoutLog log) async {
    _logs.insert(0, log);
    notifyListeners();
    await _persist();
  }

  Future<void> removeLog(String id) async {
    _logs.removeWhere((l) => l.id == id);
    notifyListeners();
    await _persist();
  }

  Future<void> clearAll() async {
    _logs.clear();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(_logs.map((l) => l.toJson()).toList()));
  }
}
