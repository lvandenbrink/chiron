import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/exercise.dart';
import '../models/progression.dart';
import '../services/notification_service.dart';

class SettingsProvider extends ChangeNotifier {
  static const _repBpmKey = 'rep_bpms';
  static const _exSettingsKey = 'exercise_settings';
  static const _programDaysKey = 'program_days';
  static const _programOrderKey = 'program_order';
  static const _programTimesPerDayKey = 'program_times_per_day';
  static const _programPhaseKey = 'program_phase';
  static const _notificationEnabledKey = 'notification_enabled';
  static const _notificationTimeKey = 'notification_time';
  static const Set<int> _defaultDays = {1, 3, 5};

  Map<String, Set<int>> _programDays = {};    // programId → scheduled days
  Map<String, int> _programTimesPerDay = {};  // programId → 1 or 2
  Map<String, int> _programPhase = {};        // programId → active phase (1-4)
  Map<String, bool> _notificationEnabled = {};
  final Map<String, int> _notificationHour = {};
  final Map<String, int> _notificationMinute = {};
  List<String> _programOrder = [];
  Map<String, int> _repBpms = {};
  Map<String, ExerciseSettings> _exerciseSettings = {};

  // ── Day schedule ────────────────────────────────────────────────────────────

  /// Days for a specific program; falls back to Mon/Wed/Fri if not configured.
  Set<int> scheduledDaysFor(String programId) =>
      _programDays[programId] ?? _defaultDays;

  bool isScheduledDayFor(String programId) =>
      scheduledDaysFor(programId).contains(DateTime.now().weekday);

  Future<void> toggleProgramDay(String programId, int weekday) async {
    final current = Set<int>.from(scheduledDaysFor(programId));
    if (current.contains(weekday)) {
      if (current.length == 1) return;
      current.remove(weekday);
    } else {
      current.add(weekday);
    }
    _programDays[programId] = current;
    notifyListeners();
    await _saveProgramDays();
  }

  // ── Times per day ────────────────────────────────────────────────────────

  int timesPerDayFor(String programId) =>
      _programTimesPerDay[programId] ?? 1;

  Future<void> setTimesPerDay(String programId, int times) async {
    _programTimesPerDay[programId] = times;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _programTimesPerDayKey,
      jsonEncode(_programTimesPerDay),
    );
  }

  // ── Program order ─────────────────────────────────────────────────────────

  List<String> get programOrder => _programOrder;

  Future<void> setProgramOrder(List<String> order) async {
    _programOrder = order;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_programOrderKey, order);
  }

  // ── Phase selection ───────────────────────────────────────────────────────

  int phaseFor(String programId) => _programPhase[programId] ?? 1;

  Future<void> setPhase(String programId, int phase) async {
    _programPhase[programId] = phase;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_programPhaseKey, jsonEncode(_programPhase));
  }

  // ── Notifications ────────────────────────────────────────────────────────

  bool notificationsEnabledFor(String programId) =>
      _notificationEnabled[programId] ?? false;

  TimeOfDay notificationTimeFor(String programId) => TimeOfDay(
        hour: _notificationHour[programId] ?? 20,
        minute: _notificationMinute[programId] ?? 0,
      );

  Future<void> setNotificationsEnabled(
      String programId, bool enabled, String programName) async {
    _notificationEnabled[programId] = enabled;
    notifyListeners();
    await _saveNotifications();
    final svc = NotificationService.instance;
    if (enabled) {
      await svc.scheduleDailyReminder(
        id: NotificationService.notifId(programId),
        title: programName,
        body: 'Je hebt vandaag nog niet geoefend.',
        time: notificationTimeFor(programId),
      );
    } else {
      await svc.cancel(NotificationService.notifId(programId));
    }
  }

  Future<void> setNotificationTime(
      String programId, TimeOfDay time, String programName) async {
    _notificationHour[programId] = time.hour;
    _notificationMinute[programId] = time.minute;
    notifyListeners();
    await _saveNotifications();
    if (notificationsEnabledFor(programId)) {
      await NotificationService.instance.scheduleDailyReminder(
        id: NotificationService.notifId(programId),
        title: programName,
        body: 'Je hebt vandaag nog niet geoefend.',
        time: time,
      );
    }
  }

  Future<void> _saveNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _notificationEnabledKey, jsonEncode(_notificationEnabled));
    final timeMap = {
      for (final k in _notificationHour.keys)
        k: {'h': _notificationHour[k]!, 'm': _notificationMinute[k] ?? 0}
    };
    await prefs.setString(_notificationTimeKey, jsonEncode(timeMap));
  }

  // ── Rep BPM (per-exercise override) ──────────────────────────────────────

  int repBpmFor(Exercise exercise) => _repBpms[exercise.id] ?? exercise.repBpm;

  Future<void> setRepBpm(String exerciseId, int bpm) async {
    _repBpms[exerciseId] = bpm;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_repBpmKey, jsonEncode(_repBpms));
  }

  // ── Exercise settings (weight + progression) ──────────────────────────────

  ExerciseSettings settingsFor(String exerciseId) =>
      _exerciseSettings[exerciseId] ?? const ExerciseSettings();

  Future<void> updateSettings(
      String exerciseId, ExerciseSettings settings) async {
    _exerciseSettings[exerciseId] = settings;
    notifyListeners();
    await _saveExerciseSettings();
  }

  Future<void> recordCompletion(String exerciseId, int defaultReps) async {
    final current = settingsFor(exerciseId);
    var updated =
        current.copyWith(completionCount: current.completionCount + 1);
    if (updated.shouldProgress(defaultReps)) {
      updated = updated.applyProgression(defaultReps);
    }
    await updateSettings(exerciseId, updated);
  }

  Exercise withExerciseSettings(Exercise exercise) {
    var result = exercise;
    final customBpm = _repBpms[exercise.id];
    if (customBpm != null) {
      result = result.copyWith(repBpm: customBpm);
    }
    final s = settingsFor(exercise.id);
    if (s.repsOverride != null) {
      result = result.copyWith(reps: s.repsOverride);
    }
    return result;
  }

  // ── Persistence ───────────────────────────────────────────────────────────

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    final savedProgramDays = prefs.getString(_programDaysKey);
    if (savedProgramDays != null) {
      final map = jsonDecode(savedProgramDays) as Map<String, dynamic>;
      _programDays = map.map((k, v) =>
          MapEntry(k, (v as List).map((d) => d as int).toSet()));
    }

    final savedOrder = prefs.getStringList(_programOrderKey);
    if (savedOrder != null) _programOrder = savedOrder;

    final savedTimesPerDay = prefs.getString(_programTimesPerDayKey);
    if (savedTimesPerDay != null) {
      final map = jsonDecode(savedTimesPerDay) as Map<String, dynamic>;
      _programTimesPerDay = map.map((k, v) => MapEntry(k, v as int));
    }

    final savedPhase = prefs.getString(_programPhaseKey);
    if (savedPhase != null) {
      final map = jsonDecode(savedPhase) as Map<String, dynamic>;
      _programPhase = map.map((k, v) => MapEntry(k, v as int));
    }

    final savedNotifEnabled = prefs.getString(_notificationEnabledKey);
    if (savedNotifEnabled != null) {
      final map = jsonDecode(savedNotifEnabled) as Map<String, dynamic>;
      _notificationEnabled = map.map((k, v) => MapEntry(k, v as bool));
    }

    final savedNotifTime = prefs.getString(_notificationTimeKey);
    if (savedNotifTime != null) {
      final map = jsonDecode(savedNotifTime) as Map<String, dynamic>;
      for (final entry in map.entries) {
        final t = entry.value as Map<String, dynamic>;
        _notificationHour[entry.key] = t['h'] as int;
        _notificationMinute[entry.key] = t['m'] as int;
      }
    }

    final savedRepBpms = prefs.getString(_repBpmKey);
    if (savedRepBpms != null) {
      final map = jsonDecode(savedRepBpms) as Map<String, dynamic>;
      _repBpms = map.map((k, v) => MapEntry(k, v as int));
    }

    final savedSettings = prefs.getString(_exSettingsKey);
    if (savedSettings != null) {
      final map = jsonDecode(savedSettings) as Map<String, dynamic>;
      _exerciseSettings = map.map((k, v) => MapEntry(
            k,
            ExerciseSettings.fromJson(v as Map<String, dynamic>),
          ));
    }

    notifyListeners();
  }

  Future<void> _saveProgramDays() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _programDaysKey,
      jsonEncode(_programDays.map((k, v) => MapEntry(k, v.toList()))),
    );
  }

  Future<void> _saveExerciseSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _exSettingsKey,
      jsonEncode(_exerciseSettings.map((k, v) => MapEntry(k, v.toJson()))),
    );
  }
}
