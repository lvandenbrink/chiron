enum OverloadType { weight, reps }

enum ScheduleUnit { workouts, weeks }

class ProgressiveOverload {
  final bool enabled;
  final OverloadType type;
  final double weightIncrement;
  final int repIncrement;
  final ScheduleUnit scheduleUnit;
  final int scheduleValue;

  const ProgressiveOverload({
    this.enabled = false,
    this.type = OverloadType.weight,
    this.weightIncrement = 2.5,
    this.repIncrement = 2,
    this.scheduleUnit = ScheduleUnit.workouts,
    this.scheduleValue = 4,
  });

  ProgressiveOverload copyWith({
    bool? enabled,
    OverloadType? type,
    double? weightIncrement,
    int? repIncrement,
    ScheduleUnit? scheduleUnit,
    int? scheduleValue,
  }) =>
      ProgressiveOverload(
        enabled: enabled ?? this.enabled,
        type: type ?? this.type,
        weightIncrement: weightIncrement ?? this.weightIncrement,
        repIncrement: repIncrement ?? this.repIncrement,
        scheduleUnit: scheduleUnit ?? this.scheduleUnit,
        scheduleValue: scheduleValue ?? this.scheduleValue,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'type': type.index,
        'weightIncrement': weightIncrement,
        'repIncrement': repIncrement,
        'scheduleUnit': scheduleUnit.index,
        'scheduleValue': scheduleValue,
      };

  factory ProgressiveOverload.fromJson(Map<String, dynamic> j) =>
      ProgressiveOverload(
        enabled: j['enabled'] ?? false,
        type: OverloadType.values[j['type'] ?? 0],
        weightIncrement: (j['weightIncrement'] ?? 2.5).toDouble(),
        repIncrement: j['repIncrement'] ?? 2,
        scheduleUnit: ScheduleUnit.values[j['scheduleUnit'] ?? 0],
        scheduleValue: j['scheduleValue'] ?? 4,
      );
}

class ExerciseSettings {
  final double weight;
  final int? repsOverride;
  final int completionCount;
  final DateTime? lastProgressDate;
  final ProgressiveOverload progression;

  const ExerciseSettings({
    this.weight = 0,
    this.repsOverride,
    this.completionCount = 0,
    this.lastProgressDate,
    this.progression = const ProgressiveOverload(),
  });

  ExerciseSettings copyWith({
    double? weight,
    int? repsOverride,
    int? completionCount,
    DateTime? lastProgressDate,
    ProgressiveOverload? progression,
  }) =>
      ExerciseSettings(
        weight: weight ?? this.weight,
        repsOverride: repsOverride ?? this.repsOverride,
        completionCount: completionCount ?? this.completionCount,
        lastProgressDate: lastProgressDate ?? this.lastProgressDate,
        progression: progression ?? this.progression,
      );

  bool shouldProgress(int defaultReps) {
    if (!progression.enabled) return false;
    switch (progression.scheduleUnit) {
      case ScheduleUnit.workouts:
        return completionCount >= progression.scheduleValue;
      case ScheduleUnit.weeks:
        if (lastProgressDate == null) return false;
        final weeks =
            DateTime.now().difference(lastProgressDate!).inDays / 7.0;
        return weeks >= progression.scheduleValue;
    }
  }

  ExerciseSettings applyProgression(int defaultReps) {
    final now = DateTime.now();
    if (progression.type == OverloadType.weight) {
      return copyWith(
        weight: weight + progression.weightIncrement,
        completionCount: 0,
        lastProgressDate: now,
      );
    } else {
      return copyWith(
        repsOverride:
            (repsOverride ?? defaultReps) + progression.repIncrement,
        completionCount: 0,
        lastProgressDate: now,
      );
    }
  }

  // How many more workouts until the next automatic progression.
  int workoutsUntilProgress() {
    if (!progression.enabled ||
        progression.scheduleUnit != ScheduleUnit.workouts) {
      return 0;
    }
    return (progression.scheduleValue - completionCount)
        .clamp(0, progression.scheduleValue);
  }

  Map<String, dynamic> toJson() => {
        'weight': weight,
        'repsOverride': repsOverride,
        'completionCount': completionCount,
        'lastProgressDate': lastProgressDate?.toIso8601String(),
        'progression': progression.toJson(),
      };

  factory ExerciseSettings.fromJson(Map<String, dynamic> j) =>
      ExerciseSettings(
        weight: (j['weight'] ?? 0.0).toDouble(),
        repsOverride: j['repsOverride'] as int?,
        completionCount: j['completionCount'] ?? 0,
        lastProgressDate: j['lastProgressDate'] != null
            ? DateTime.parse(j['lastProgressDate'] as String)
            : null,
        progression: j['progression'] != null
            ? ProgressiveOverload.fromJson(
                j['progression'] as Map<String, dynamic>)
            : const ProgressiveOverload(),
      );
}
