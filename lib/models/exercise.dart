enum FrequencyType { daily, nTimesPerWeek }

enum ExerciseType { timed, reps, instruction, steps }

class ExerciseStep {
  final String label;
  final String instruction;

  const ExerciseStep({required this.label, required this.instruction});
}

class Exercise {
  final String id;
  final String name;
  final String? description;
  final int sets;
  final int? reps;
  final int? durationSeconds;
  final int repBpm;
  final FrequencyType frequency;
  final ExerciseType type;
  final List<ExerciseStep>? steps;
  final int? cycleCount;
  final bool hasWeight;
  final bool unilateral;
  final int? phase;
  final int? prepDurationSeconds;
  final int? restAfterExerciseSeconds;

  const Exercise({
    required this.id,
    required this.name,
    this.description,
    required this.sets,
    this.reps,
    this.durationSeconds,
    this.repBpm = 20,
    required this.frequency,
    required this.type,
    this.steps,
    this.cycleCount,
    this.hasWeight = false,
    this.unilateral = false,
    this.prepDurationSeconds,
    this.restAfterExerciseSeconds,
    this.phase,
  });

  Exercise copyWith({int? repBpm, int? reps}) => Exercise(
        id: id,
        name: name,
        description: description,
        sets: sets,
        reps: reps ?? this.reps,
        durationSeconds: durationSeconds,
        repBpm: repBpm ?? this.repBpm,
        frequency: frequency,
        type: type,
        steps: steps,
        cycleCount: cycleCount,
        hasWeight: hasWeight,
        unilateral: unilateral,
        prepDurationSeconds: prepDurationSeconds,
        restAfterExerciseSeconds: restAfterExerciseSeconds,
        phase: phase,
      );

  String get setsRepsLabel {
    final perSide = unilateral ? ' per kant' : '';
    if (type == ExerciseType.timed && durationSeconds != null) {
      final d = durationSeconds!;
      final label = d % 60 == 0 ? '${d ~/ 60}m' : '${d}s';
      return '$sets sets × $label$perSide';
    }
    if (type == ExerciseType.reps && reps != null) {
      return '$sets sets × $reps reps$perSide';
    }
    return '$sets sets';
  }
}
