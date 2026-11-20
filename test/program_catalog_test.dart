import 'dart:io';

import 'package:chiron/data/program_catalog.dart';
import 'package:chiron/models/exercise.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/programs.dart';

ProgramCatalog parse(String yaml) => ProgramCatalog.parse({'test.yaml': yaml});

Matcher throwsFormat(String message) => throwsA(
  isA<ProgramFormatException>().having(
    (e) => e.message,
    'message',
    contains(message),
  ),
);

const _program = '''
id: p
name: P
description: D
color: "#546E7A"
emoji: "💪"
frequency: daily
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads the bundled example programs from the asset manifest', () async {
    final catalog = await ProgramCatalog.load(rootBundle);
    expect(catalog.programs.map((p) => p.id), ['demo', 'demo_phases']);
  });

  test('production programs are valid', () {
    const dir = 'assets/programs/production';
    if (!Directory(dir).existsSync()) return markTestSkipped('$dir not found');
    expect(loadCatalogFromDir(dir).programs, isNotEmpty);
  });

  test('applies defaults and numbers phases in order', () {
    final program = parse('''
$_program
exercises:
  - id: always
    name: Always
    type: metronome
phases:
  - label: First
    exercises:
      - id: a
        name: A
        type: reps
        frequency: nTimesPerWeek
        reps: 8
  - label: Second
    exercises:
      - id: b
        name: B
        type: timed
        durationSeconds: 30
        description: >
          Folded
          text
''').programs.single;

    expect(program.color.toARGB32(), 0xFF546E7A);
    expect(program.phaseLabels, {1: 'First', 2: 'Second'});
    expect(program.exercises.map((e) => (e.id, e.phase)), [
      ('always', null),
      ('a', 1),
      ('b', 2),
    ]);
    final [always, a, b] = program.exercises;
    expect(always.sets, 1);
    expect(always.repBpm, 20);
    expect(always.frequency, FrequencyType.daily);
    expect(a.frequency, FrequencyType.nTimesPerWeek);
    expect(b.description, 'Folded text');
  });

  test('reports the file, exercise and field of an error', () {
    expect(
      () => parse('$_program\nexercises:\n  - {id: x, name: X, type: reps}'),
      throwsFormat("test.yaml › x: missing 'reps'"),
    );
    expect(
      () => parse(
        '$_program\nexercises:\n'
        '  - {id: x, name: X, type: timed, durationSecond: 3}',
      ),
      throwsFormat("unknown key 'durationSecond'"),
    );
    expect(
      () => parse('$_program\nexercises:\n  - {id: x, name: X, type: jump}'),
      throwsFormat("'type' must be one of timed, reps, steps, metronome"),
    );
    expect(
      () => parse(
        '$_program\nexercises:\n'
        '  - {id: x, name: X, type: reps, reps: many}',
      ),
      throwsFormat("'reps' must be a whole number"),
    );
    expect(
      () => parse(_program),
      throwsFormat("needs 'exercises' or 'phases'"),
    );
    expect(() => parse('id: [unclosed'), throwsFormat('test.yaml:'));
  });

  test('rejects duplicate exercise ids across files', () {
    const exercise = 'exercises:\n  - {id: x, name: X, type: metronome}';
    expect(
      () => ProgramCatalog.parse({
        'a.yaml': '$_program$exercise',
        'b.yaml': '${_program.replaceFirst('id: p', 'id: q')}$exercise',
      }),
      throwsFormat("Duplicate exercise id 'x'"),
    );
  });
}
