import 'exercise.dart';

class ExerciseLog {
  final String exerciseId;
  final String name;
  final int sets;
  final int? reps;
  final double weight;
  final bool hasWeight;
  final ExerciseType type;
  final int? durationSeconds;
  final bool unilateral;

  const ExerciseLog({
    required this.exerciseId,
    required this.name,
    required this.sets,
    this.reps,
    this.weight = 0,
    this.hasWeight = false,
    required this.type,
    this.durationSeconds,
    this.unilateral = false,
  });

  factory ExerciseLog.fromExercise(Exercise exercise, {double weight = 0}) =>
      ExerciseLog(
        exerciseId: exercise.id,
        name: exercise.name,
        sets: exercise.sets,
        reps: exercise.reps,
        weight: weight,
        hasWeight: exercise.hasWeight,
        type: exercise.type,
        durationSeconds: exercise.durationSeconds,
        unilateral: exercise.unilateral,
      );

  String get label {
    final perSide = unilateral ? '/kant' : '';
    switch (type) {
      case ExerciseType.timed:
        if (durationSeconds != null) {
          final d = durationSeconds!;
          final dur = d >= 60 && d % 60 == 0 ? '${d ~/ 60} min' : '${d}s';
          return '$sets × $dur$perSide';
        }
        return '$sets sets';
      case ExerciseType.reps:
        return reps != null ? '$sets × $reps reps$perSide' : '$sets sets';
      default:
        return '$sets sets';
    }
  }

  Map<String, dynamic> toJson() => {
        'exerciseId': exerciseId,
        'name': name,
        'sets': sets,
        'reps': reps,
        'weight': weight,
        'hasWeight': hasWeight,
        'type': type.index,
        'durationSeconds': durationSeconds,
        'unilateral': unilateral,
      };

  factory ExerciseLog.fromJson(Map<String, dynamic> j) => ExerciseLog(
        exerciseId: j['exerciseId'] as String,
        name: j['name'] as String,
        sets: j['sets'] as int,
        reps: j['reps'] as int?,
        weight: (j['weight'] ?? 0.0).toDouble(),
        hasWeight: j['hasWeight'] ?? false,
        type: ExerciseType.values[j['type'] ?? 0],
        durationSeconds: j['durationSeconds'] as int?,
        unilateral: j['unilateral'] ?? false,
      );
}

class WorkoutLog {
  final String id;
  final DateTime date;
  final String programId;
  final String programName;
  final List<ExerciseLog> exercises;

  const WorkoutLog({
    required this.id,
    required this.date,
    required this.programId,
    required this.programName,
    required this.exercises,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'programId': programId,
        'programName': programName,
        'exercises': exercises.map((e) => e.toJson()).toList(),
      };

  factory WorkoutLog.fromJson(Map<String, dynamic> j) => WorkoutLog(
        id: j['id'] as String,
        date: DateTime.parse(j['date'] as String),
        programId: j['programId'] as String,
        programName: j['programName'] as String,
        exercises: (j['exercises'] as List)
            .map((e) => ExerciseLog.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
