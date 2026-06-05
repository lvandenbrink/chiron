// Tests that the correct audio beeps are produced during a workout.
//
// Audio contract:
//   • playExerciseStart — once per set (and once per side for unilateral),
//                         after the prep / side-switch countdown finishes
//   • playTick          — reps only: once per rep except the last (N-1 per set side)
//   • playSetComplete   — once per set side when it ends
//                         (reps: last rep tick; timed: countdown reaches zero)
//
// Timing reference (all durations in whole seconds):
//   firstPrepDurationSeconds   = 10  (first set of a workout)
//   shortPrepDurationSeconds   = 3   (subsequent sets, after rest)
//   switchSidesDurationSeconds = 3   (unilateral: side-switch countdown)
//   restDurationSeconds        = 30  (rest between sets)
//   display pause              = 1   (reps only: after setComplete, before phase transition)

import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fysio_app/models/exercise.dart';
import 'package:fysio_app/models/program.dart';
import 'package:fysio_app/providers/workout_provider.dart';
import 'package:fysio_app/services/audio_service.dart';

// ---------------------------------------------------------------------------
// Fake audio service — counts calls without touching AudioPlayer
// ---------------------------------------------------------------------------

class _FakeAudio implements AudioService {
  int exerciseStart = 0;
  int tick = 0;
  int setComplete = 0;

  @override
  Future<void> playExerciseStart() async => exerciseStart++;
  @override
  Future<void> playTick() async => tick++;
  @override
  Future<void> playSetComplete() async => setComplete++;
  @override
  void dispose() {}
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _allDays = {1, 2, 3, 4, 5, 6, 7};

Program _prog(Exercise e) => Program(
  id: 'test',
  name: 'Test',
  description: '',
  color: const Color(0xFF000000),
  emoji: '',
  exercises: [e],
);

// Total elapsed seconds to complete a bilateral reps workout of [sets] sets.
// setComplete fires on the Nth rep tick, then a 1 s display pause before
// the phase transitions so the user sees the final rep count.
int _totalSeconds({required int sets, required int reps, required int repBpm}) {
  final repIntervalSec = 60 ~/ repBpm;
  final oneSetSec = reps * repIntervalSec + 1; // N ticks + display pause
  final firstSetSec = WorkoutProvider.firstPrepDurationSeconds + oneSetSec;
  // The rest countdown fires one extra tick: actual duration = restDurationSeconds + 1.
  final restActualSec = WorkoutProvider.restDurationSeconds + 1;
  final laterSetSec =
      restActualSec + WorkoutProvider.shortPrepDurationSeconds + oneSetSec;
  return firstSetSec + (sets - 1) * laterSetSec;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeAudio audio;
  late WorkoutProvider provider;

  setUp(() {
    audio = _FakeAudio();
    provider = WorkoutProvider(audioService: audio);
  });

  tearDown(() => provider.dispose());

  // ── End-to-end ─────────────────────────────────────────────────────────────

  test('reps: 2 sets × 3 reps — end-to-end counts', () {
    const repBpm = 30;
    fakeAsync((fake) {
      provider.startWorkout(
        _prog(
          const Exercise(
            id: 'e',
            name: 'E',
            sets: 2,
            reps: 3,
            repBpm: repBpm,
            frequency: FrequencyType.daily,
            type: ExerciseType.reps,
          ),
        ),
        _allDays,
      );
      fake.elapse(
        Duration(seconds: _totalSeconds(sets: 2, reps: 3, repBpm: repBpm)),
      );
      fake.flushMicrotasks();

      expect(audio.exerciseStart, 2);
      expect(audio.tick, 4, reason: '2×3 reps, no tick on the last rep of each set');
      expect(audio.setComplete, 2, reason: 'one per set');
    });
  });

  test('timed: 2 sets × 30 s — end-to-end counts', () {
    fakeAsync((fake) {
      provider.startWorkout(
        _prog(
          const Exercise(
            id: 'e',
            name: 'E',
            sets: 2,
            durationSeconds: 30,
            frequency: FrequencyType.daily,
            type: ExerciseType.timed,
          ),
        ),
        _allDays,
      );
      // 30 s at 60 BPM matches the timed countdown timing (durationSeconds + 1 ticks).
      fake.elapse(
        Duration(seconds: _totalSeconds(sets: 2, reps: 30, repBpm: 60)),
      );
      fake.flushMicrotasks();

      expect(audio.exerciseStart, 2);
      expect(audio.tick, 0, reason: 'timed exercises do not use tick');
      expect(audio.setComplete, 2, reason: 'one per set');
    });
  });

  // ── Prep ───────────────────────────────────────────────────────────────────

  group('Prep', () {
    test('no beeps before prep countdown completes', () {
      fakeAsync((fake) {
        provider.startWorkout(
          _prog(
            const Exercise(
              id: 'e',
              name: 'E',
              sets: 1,
              reps: 3,
              repBpm: 60,
              frequency: FrequencyType.daily,
              type: ExerciseType.reps,
            ),
          ),
          _allDays,
        );

        fake.elapse(
          const Duration(seconds: WorkoutProvider.firstPrepDurationSeconds - 1),
        );

        expect(audio.exerciseStart, 0, reason: 'prep not done yet');
        expect(audio.tick, 0, reason: 'no reps started during prep');
      });
    });

    test('skipPrep fires exerciseStart immediately', () {
      fakeAsync((fake) {
        provider.startWorkout(
          _prog(
            const Exercise(
              id: 'e',
              name: 'E',
              sets: 1,
              reps: 3,
              repBpm: 60,
              frequency: FrequencyType.daily,
              type: ExerciseType.reps,
            ),
          ),
          _allDays,
        );

        expect(audio.exerciseStart, 0);
        provider.skipPrep();
        expect(audio.exerciseStart, 1);
      });
    });
  });

  // ── Reps exercise ──────────────────────────────────────────────────────────

  group('Reps exercise', () {
    const repBpm = 60;

    for (final reps in [1, 3, 5, 10]) {
      test('$reps rep(s) → ${reps - 1} tick(s), setComplete on the last', () {
        fakeAsync((fake) {
          provider.startWorkout(
            _prog(
              Exercise(
                id: 'e',
                name: 'E',
                sets: 1,
                reps: reps,
                repBpm: repBpm,
                frequency: FrequencyType.daily,
                type: ExerciseType.reps,
              ),
            ),
            _allDays,
          );

          fake.elapse(
            Duration(seconds: _totalSeconds(sets: 1, reps: reps, repBpm: repBpm)),
          );
          fake.flushMicrotasks();

          expect(audio.tick, reps - 1,
              reason: 'tick for every rep except the last (setComplete)');
          expect(audio.setComplete, 1,
              reason: 'setComplete is the single done signal on the last rep');
        });
      });
    }

    test('first tick fires after one interval, not immediately after exerciseStart', () {
      fakeAsync((fake) {
        provider.startWorkout(
          _prog(
            const Exercise(
              id: 'e',
              name: 'E',
              sets: 1,
              reps: 5,
              repBpm: repBpm,
              frequency: FrequencyType.daily,
              type: ExerciseType.reps,
            ),
          ),
          _allDays,
        );

        fake.elapse(
          const Duration(seconds: WorkoutProvider.firstPrepDurationSeconds),
        );
        fake.flushMicrotasks();
        expect(audio.tick, 0, reason: 'no tick immediately after start sound');

        fake.elapse(const Duration(seconds: 1)); // 60 BPM → 1 s/rep
        expect(audio.tick, 1, reason: 'first tick fires after one interval');
      });
    });

    test('setComplete not fired before the last rep tick', () {
      fakeAsync((fake) {
        const reps = 4;

        provider.startWorkout(
          _prog(
            const Exercise(
              id: 'e',
              name: 'E',
              sets: 1,
              reps: reps,
              repBpm: repBpm,
              frequency: FrequencyType.daily,
              type: ExerciseType.reps,
            ),
          ),
          _allDays,
        );

        fake.elapse(
          Duration(
            seconds:
                WorkoutProvider.firstPrepDurationSeconds + (reps - 1) * (60 ~/ repBpm),
          ),
        );

        expect(audio.setComplete, 0, reason: 'last rep tick has not fired yet');
      });
    });

    test('3 sets × 4 reps — all counts correct', () {
      fakeAsync((fake) {
        const sets = 3;
        const reps = 4;

        provider.startWorkout(
          _prog(
            const Exercise(
              id: 'e',
              name: 'E',
              sets: sets,
              reps: reps,
              repBpm: repBpm,
              frequency: FrequencyType.daily,
              type: ExerciseType.reps,
            ),
          ),
          _allDays,
        );

        fake.elapse(
          Duration(seconds: _totalSeconds(sets: sets, reps: reps, repBpm: repBpm)),
        );
        fake.flushMicrotasks();

        expect(audio.exerciseStart, sets, reason: 'one per set');
        expect(audio.tick, sets * (reps - 1),
            reason: 'N-1 ticks per set, setComplete covers the last rep');
        expect(audio.setComplete, sets, reason: 'one per set');
      });
    });

    test('display pause: set 2 has not started during the 1 s pause after setComplete', () {
      fakeAsync((fake) {
        const reps = 3;
        const repIntervalSec = 60 ~/ repBpm;

        provider.startWorkout(
          _prog(
            const Exercise(
              id: 'e',
              name: 'E',
              sets: 2,
              reps: reps,
              repBpm: repBpm,
              frequency: FrequencyType.daily,
              type: ExerciseType.reps,
            ),
          ),
          _allDays,
        );

        fake.elapse(
          Duration(
            seconds: WorkoutProvider.firstPrepDurationSeconds + reps * repIntervalSec,
          ),
        );
        fake.flushMicrotasks();
        expect(audio.setComplete, 1, reason: 'setComplete fires on the last rep tick');
        expect(audio.exerciseStart, 1,
            reason: 'set 2 prep has not started — still in display pause');
      });
    });
  });

  // ── Timed exercise ─────────────────────────────────────────────────────────

  group('Timed exercise', () {
    test('setComplete fires on the extra tick after the countdown reaches zero, not before', () {
      const durationSeconds = 5;
      fakeAsync((fake) {
        provider.startWorkout(
          _prog(
            const Exercise(
              id: 'e',
              name: 'E',
              sets: 1,
              durationSeconds: durationSeconds,
              frequency: FrequencyType.daily,
              type: ExerciseType.timed,
            ),
          ),
          _allDays,
        );

        // At firstPrep + durationSeconds the remaining counter just hit 0 —
        // the done-tick fires one second later.
        fake.elapse(
          const Duration(
            seconds: WorkoutProvider.firstPrepDurationSeconds + durationSeconds,
          ),
        );
        expect(audio.setComplete, 0, reason: 'countdown at 0 but done-tick not fired yet');

        fake.elapse(const Duration(seconds: 1));
        fake.flushMicrotasks();
        expect(audio.setComplete, 1);
      });
    });
  });

  // ── Unilateral exercise ────────────────────────────────────────────────────

  group('Unilateral exercise', () {
    test('reps: exerciseStart fires for left side (prep) and right side (side switch)', () {
      // 1 set, 2 reps at 60 BPM.
      // Timing: firstPrep(10) + left(2+1) + sideSwitch(3) + right(2+1) = 19 s.
      fakeAsync((fake) {
        provider.startWorkout(
          _prog(
            const Exercise(
              id: 'e',
              name: 'E',
              sets: 1,
              reps: 2,
              repBpm: 60,
              frequency: FrequencyType.daily,
              type: ExerciseType.reps,
              unilateral: true,
            ),
          ),
          _allDays,
        );

        fake.elapse(const Duration(seconds: 19));
        fake.flushMicrotasks();

        expect(audio.exerciseStart, 2, reason: 'one for each side');
        expect(audio.setComplete, 2, reason: 'one for each side');
        expect(audio.tick, 2, reason: '1 tick per side (2 reps → N-1 = 1)');
      });
    });

    test('timed: exerciseStart fires for left side (prep) and right side (side switch)', () {
      // 1 set, 5 s duration.
      // Timing: firstPrep(10) + left(5+1) + sideSwitch(3) + right(5+1) = 25 s.
      fakeAsync((fake) {
        provider.startWorkout(
          _prog(
            const Exercise(
              id: 'e',
              name: 'E',
              sets: 1,
              durationSeconds: 5,
              frequency: FrequencyType.daily,
              type: ExerciseType.timed,
              unilateral: true,
            ),
          ),
          _allDays,
        );

        fake.elapse(const Duration(seconds: 25));
        fake.flushMicrotasks();

        expect(audio.exerciseStart, 2, reason: 'one for each side');
        expect(audio.setComplete, 2, reason: 'one for each side');
        expect(audio.tick, 0, reason: 'timed exercises do not use tick');
      });
    });
  });
}
