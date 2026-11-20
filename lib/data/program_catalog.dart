import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';

import '../models/exercise.dart';
import '../models/program.dart';

/// Thrown when a program YAML file is malformed. The message names the file
/// and the location of the problem, e.g. `rug.yaml › rug_side_plank: …`.
class ProgramFormatException implements Exception {
  final String message;
  const ProgramFormatException(this.message);

  @override
  String toString() => 'ProgramFormatException: $message';
}

/// All programs available in this build, parsed from the YAML files in
/// `assets/programs/<flavor>/`. Files are read in alphabetical order.
class ProgramCatalog {
  final List<Program> programs;

  const ProgramCatalog(this.programs);

  static String get assetDir =>
      'assets/programs/${appFlavor == 'production' ? 'production' : 'example'}/';

  static Future<ProgramCatalog> load(AssetBundle bundle) async {
    final manifest = await AssetManifest.loadFromAssetBundle(bundle);
    final paths =
        manifest
            .listAssets()
            .where((p) => p.startsWith(assetDir) && p.endsWith('.yaml'))
            .toList()
          ..sort();
    return ProgramCatalog.parse({
      for (final path in paths) path: await bundle.loadString(path),
    });
  }

  /// Parses YAML sources keyed by file name and checks that all program and
  /// exercise ids are unique.
  factory ProgramCatalog.parse(Map<String, String> sources) {
    final programs = [
      for (final MapEntry(key: file, value: source) in sources.entries)
        _parseProgram(file.split('/').last, source),
    ];
    _requireUnique(programs.map((p) => p.id), 'program id');
    _requireUnique(
      programs.expand((p) => p.exercises).map((e) => e.id),
      'exercise id',
    );
    return ProgramCatalog(programs);
  }

  Program? byId(String id) {
    for (final p in programs) {
      if (p.id == id) return p;
    }
    return null;
  }
}

void _requireUnique(Iterable<String> ids, String what) {
  final seen = <String>{};
  for (final id in ids) {
    if (!seen.add(id)) throw ProgramFormatException("Duplicate $what '$id'");
  }
}

Program _parseProgram(String file, String source) {
  final Object? doc;
  try {
    doc = loadYaml(source);
  } on YamlException catch (e) {
    final line = (e.span?.start.line ?? 0) + 1;
    throw ProgramFormatException('$file: ${e.message} (line $line)');
  }
  final p = _Fields(doc, file, const {
    'id', 'name', 'description', 'color', 'emoji', 'frequency', //
    'exercises', 'phases',
  });
  final defaultFrequency = p.optionalEnum('frequency', FrequencyType.values);
  Exercise exercise(Object? node, int? phase) =>
      _parseExercise(node, file, defaultFrequency, phase);

  // Exercises at the top level show in every phase; phases are numbered 1..n.
  final exercises = [
    for (final node in p.list('exercises')) exercise(node, null),
  ];
  final phaseLabels = <int, String>{};
  for (final (i, node) in p.list('phases').indexed) {
    final phase = _Fields(node, '$file › phases[$i]', const {
      'label',
      'exercises',
    });
    phaseLabels[i + 1] = phase.required<String>('label');
    exercises.addAll(phase.list('exercises').map((n) => exercise(n, i + 1)));
  }
  if (exercises.isEmpty) {
    throw ProgramFormatException("$file: needs 'exercises' or 'phases'");
  }

  return Program(
    id: p.required<String>('id'),
    name: p.required<String>('name'),
    description: p.required<String>('description'),
    color: p.color('color'),
    emoji: p.required<String>('emoji'),
    exercises: exercises,
    phaseLabels: phaseLabels.isEmpty ? null : phaseLabels,
  );
}

Exercise _parseExercise(
  Object? node,
  String file,
  FrequencyType? defaultFrequency,
  int? phase,
) {
  final id = node is Map ? node['id'] : null;
  final e = _Fields(node, '$file › ${id ?? 'exercise'}', const {
    'id', 'name', 'description', 'type', 'frequency', 'sets', 'reps', //
    'durationSeconds', 'repBpm', 'steps', 'cycleCount', 'hasWeight',
    'unilateral', 'prepDurationSeconds', 'restAfterExerciseSeconds',
  });
  final type = e.requiredEnum('type', ExerciseType.values);
  final frequency =
      e.optionalEnum('frequency', FrequencyType.values) ?? defaultFrequency;
  if (frequency == null) {
    e.fail("missing 'frequency' (set it on the exercise or the program)");
  }
  final reps = e.optional<int>('reps');
  final durationSeconds = e.optional<int>('durationSeconds');
  if (type == ExerciseType.reps && reps == null) e.fail("missing 'reps'");
  if (type == ExerciseType.timed && durationSeconds == null) {
    e.fail("missing 'durationSeconds'");
  }
  final steps = e.list('steps').indexed.map((entry) {
    final s = _Fields(entry.$2, '${e.path} › steps[${entry.$1}]', const {
      'label',
      'instruction',
    });
    return ExerciseStep(
      label: s.required<String>('label'),
      instruction: s.required<String>('instruction').trimRight(),
    );
  }).toList();

  return Exercise(
    id: e.required<String>('id'),
    name: e.required<String>('name'),
    description: e.optional<String>('description')?.trimRight(),
    type: type,
    frequency: frequency,
    sets: e.optional<int>('sets') ?? 1,
    reps: reps,
    durationSeconds: durationSeconds,
    repBpm: e.optional<int>('repBpm') ?? 20,
    steps: steps.isEmpty ? null : steps,
    cycleCount: e.optional<int>('cycleCount'),
    hasWeight: e.optional<bool>('hasWeight') ?? false,
    unilateral: e.optional<bool>('unilateral') ?? false,
    prepDurationSeconds: e.optional<int>('prepDurationSeconds'),
    restAfterExerciseSeconds: e.optional<int>('restAfterExerciseSeconds'),
    phase: phase,
  );
}

/// Typed access to a YAML mapping that reports errors with their location
/// and rejects unknown keys (catches typos such as `durationSecond`).
class _Fields {
  final Map<dynamic, dynamic> _map;
  final String path;

  _Fields(Object? node, this.path, Set<String> allowedKeys)
    : _map = node is Map ? node : const {} {
    if (node is! Map) fail('expected a mapping');
    final unknown = _map.keys.where((k) => !allowedKeys.contains(k));
    if (unknown.isNotEmpty) fail("unknown key '${unknown.first}'");
  }

  Never fail(String message) => throw ProgramFormatException('$path: $message');

  T? optional<T>(String key) {
    final value = _map[key];
    if (value == null || value is T) return value as T?;
    fail("'$key' must be ${_typeName<T>()}, got '$value'");
  }

  T required<T>(String key) => optional<T>(key) ?? fail("missing '$key'");

  List<Object?> list(String key) => optional<List>(key)?.cast() ?? const [];

  E? optionalEnum<E extends Enum>(String key, List<E> values) {
    final name = optional<String>(key);
    if (name == null) return null;
    for (final v in values) {
      if (v.name == name) return v;
    }
    fail(
      "'$key' must be one of ${values.map((v) => v.name).join(', ')}, "
      "got '$name'",
    );
  }

  E requiredEnum<E extends Enum>(String key, List<E> values) =>
      optionalEnum(key, values) ?? fail("missing '$key'");

  Color color(String key) {
    final hex = required<String>(key);
    if (!RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(hex)) {
      fail("'$key' must look like '#546E7A', got '$hex'");
    }
    return Color(0xFF000000 | int.parse(hex.substring(1), radix: 16));
  }

  static String _typeName<T>() => switch (T) {
    const (int) => 'a whole number',
    const (bool) => 'true or false',
    const (String) => 'text',
    _ => 'a list',
  };
}
