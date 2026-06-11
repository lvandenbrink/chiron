// Tests for NotificationService.shouldSuppressNotificationToday — the pure
// function that decides whether to reschedule a daily reminder from tomorrow
// after a workout completion.
//
// shouldSuppressNotificationToday returns:
//   true  → call rescheduleFromTomorrow (notification suppressed for today)
//   false → leave the notification as-is  (notification may still fire today)
//
// Inputs:
//   notificationsEnabled — user opted in to reminders for this program
//   hasExercisesToday    — program has exercises to do today (false when all
//                          exercises are nTimesPerWeek and today is not a
//                          scheduled training day)
//   timesPerDay          — how many sessions per day the user configured
//   completionsToday     — sessions completed today, INCLUDING the current one

import 'package:chiron/services/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

// Convenience wrapper so tests read like English.
bool _shouldSuppress({
  bool notificationsEnabled = true,
  bool hasExercisesToday = true,
  int timesPerDay = 1,
  int completionsToday = 1,
}) => NotificationService.shouldSuppressNotificationToday(
  notificationsEnabled: notificationsEnabled,
  hasExercisesToday: hasExercisesToday,
  timesPerDay: timesPerDay,
  completionsToday: completionsToday,
);

void main() {
  // ── Should notify (suppress = false) ───────────────────────────────────────

  group('notification fires — should NOT suppress', () {
    test('notifications disabled → nothing to suppress', () {
      expect(
        _shouldSuppress(notificationsEnabled: false, completionsToday: 0),
        isFalse,
      );
    });

    test('notifications disabled even if done today', () {
      // No scheduled notification → rescheduling is a no-op; return false
      // to avoid a spurious reschedule call.
      expect(
        _shouldSuppress(notificationsEnabled: false, completionsToday: 1),
        isFalse,
      );
    });

    test('exercise not done today (1×/day) — notification should fire', () {
      expect(_shouldSuppress(timesPerDay: 1, completionsToday: 0), isFalse);
    });

    test(
      'exercise done on other days but not today — notification should fire',
      () {
        // Same state as "not done today" from the function's perspective.
        expect(_shouldSuppress(timesPerDay: 1, completionsToday: 0), isFalse);
      },
    );

    test(
      'twice daily configured, done only once — notification should fire',
      () {
        expect(_shouldSuppress(timesPerDay: 2, completionsToday: 1), isFalse);
      },
    );

    test(
      'three times daily configured, done twice — notification should fire',
      () {
        expect(_shouldSuppress(timesPerDay: 3, completionsToday: 2), isFalse);
      },
    );
  });

  // ── Should not notify (suppress = true) ────────────────────────────────────

  group('notification suppressed — should reschedule from tomorrow', () {
    test('exercise done today (1×/day)', () {
      expect(_shouldSuppress(timesPerDay: 1, completionsToday: 1), isTrue);
    });

    test('twice daily configured, done twice', () {
      expect(_shouldSuppress(timesPerDay: 2, completionsToday: 2), isTrue);
    });

    test('three times daily configured, done all three', () {
      expect(_shouldSuppress(timesPerDay: 3, completionsToday: 3), isTrue);
    });

    test('nTimesPerWeek exercise — today is not a scheduled day', () {
      // When all exercises are nTimesPerWeek and today is not in the schedule,
      // hasExercisesToday is false. The notification should be suppressed so
      // the user is not bugged on a rest day.
      expect(
        _shouldSuppress(hasExercisesToday: false, completionsToday: 0),
        isTrue,
      );
    });

    test(
      'nTimesPerWeek exercise — not scheduled today — notifications enabled',
      () {
        expect(
          _shouldSuppress(
            notificationsEnabled: true,
            hasExercisesToday: false,
            timesPerDay: 1,
            completionsToday: 0,
          ),
          isTrue,
        );
      },
    );
  });

  // ── Edge cases ─────────────────────────────────────────────────────────────

  group('edge cases', () {
    test('over-completed (done more than timesPerDay) → suppress', () {
      expect(_shouldSuppress(timesPerDay: 2, completionsToday: 3), isTrue);
    });

    test(
      'notifications disabled + not a scheduled day → false (nothing to suppress)',
      () {
        expect(
          _shouldSuppress(
            notificationsEnabled: false,
            hasExercisesToday: false,
            completionsToday: 0,
          ),
          isFalse,
        );
      },
    );

    test('mixed program (daily + nTimesPerWeek) on a non-nTimesPerWeek day', () {
      // Daily exercises exist → hasExercisesToday = true even if today is
      // not a scheduled nTimesPerWeek day. Completion count drives the result.
      expect(
        _shouldSuppress(
          hasExercisesToday: true, // daily exercises make it a workout day
          timesPerDay: 1,
          completionsToday: 0,
        ),
        isFalse,
        reason: 'daily exercises still need doing today — do not suppress',
      );
      expect(
        _shouldSuppress(
          hasExercisesToday: true,
          timesPerDay: 1,
          completionsToday: 1,
        ),
        isTrue,
        reason: 'daily exercises done — suppress',
      );
    });

    test('twice daily: first completion should not suppress', () {
      expect(_shouldSuppress(timesPerDay: 2, completionsToday: 1), isFalse);
    });

    test('twice daily: second completion should suppress', () {
      expect(_shouldSuppress(timesPerDay: 2, completionsToday: 2), isTrue);
    });

    test('completionsToday exactly equals timesPerDay boundary', () {
      for (final n in [1, 2, 3, 5]) {
        expect(
          _shouldSuppress(timesPerDay: n, completionsToday: n - 1),
          isFalse,
          reason: '$n-1 completions of $n → still needs one more',
        );
        expect(
          _shouldSuppress(timesPerDay: n, completionsToday: n),
          isTrue,
          reason: '$n completions of $n → done',
        );
      }
    });
  });
}
