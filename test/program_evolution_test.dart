import 'package:chiron/models/exercise.dart';
import 'package:chiron/models/workout_log.dart';
import 'package:chiron/providers/history_provider.dart';
import 'package:chiron/providers/settings_provider.dart';
import 'package:chiron/screens/program_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/programs.dart';

void main() {
  final program = exampleCatalog.byId('demo')!;
  final [balance, squat, rdl, ...] = program.exercises;

  Future<HistoryProvider> historyWith(
    List<(DateTime, List<Exercise>)> workouts,
  ) async {
    final history = HistoryProvider();
    for (final (i, (date, exercises)) in workouts.indexed) {
      await history.addLog(
        WorkoutLog(
          id: '$i',
          date: date,
          programId: program.id,
          programName: program.name,
          exercises: exercises.map(ExerciseLog.fromExercise).toList(),
        ),
      );
    }
    return history;
  }

  Future<void> pumpProgramScreen(
    WidgetTester tester,
    HistoryProvider history,
  ) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: SettingsProvider()),
          ChangeNotifierProvider.value(value: history),
        ],
        child: MaterialApp(home: ProgramScreen(program: program)),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The chip labels shown under a week heading, in display order.
  List<String> chipsOf(WidgetTester tester, String week) {
    final row = find
        .ancestor(of: find.text(week), matching: find.byType(Column))
        .first;
    return tester
        .widgetList<Text>(
          find.descendant(
            of: find.descendant(of: row, matching: find.byType(Wrap)),
            matching: find.byType(Text),
          ),
        )
        .map((t) => t.data!)
        .toList();
  }

  /// Whether the chip is highlighted as new compared to the previous week.
  bool isHighlighted(WidgetTester tester, String week, String exercise) {
    final row = find
        .ancestor(of: find.text(week), matching: find.byType(Column))
        .first;
    final chip = tester.widget<Container>(
      find
          .ancestor(
            of: find.descendant(of: row, matching: find.text(exercise)),
            matching: find.byType(Container),
          )
          .first,
    );
    return (chip.decoration! as BoxDecoration).color ==
        program.color.withValues(alpha: 0.15);
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'groups logged workouts by ISO week and highlights new exercises',
    (tester) async {
      final history = await historyWith([
        // Added out of order: the section sorts weeks chronologically.
        (DateTime(2026, 6, 15), [rdl, squat]), // week 25
        (DateTime(2026, 6, 1), [balance]), // Monday, week 23
        (DateTime(2026, 6, 7), [squat]), // Sunday, still week 23
      ]);
      await pumpProgramScreen(tester, history);

      // The section is below the exercise list, so scroll it into view.
      await tester.scrollUntilVisible(
        find.text('Verloop'),
        300,
        scrollable: find.byType(Scrollable).first,
      );

      const week23 = 'Week 23 · 2026', week25 = 'Week 25 · 2026';
      expect(
        tester.getTopLeft(find.text(week23)).dy <
            tester.getTopLeft(find.text(week25)).dy,
        isTrue,
      );
      // Chips follow program order, not log order.
      expect(chipsOf(tester, week23), [balance.name, squat.name]);
      expect(chipsOf(tester, week25), [squat.name, rdl.name]);

      expect(
        isHighlighted(tester, week23, balance.name),
        isFalse,
        reason: 'the first week has nothing to compare with',
      );
      expect(isHighlighted(tester, week25, squat.name), isFalse);
      expect(isHighlighted(tester, week25, rdl.name), isTrue);
    },
  );

  testWidgets('is hidden until there are workouts in two different weeks', (
    tester,
  ) async {
    final history = await historyWith([
      (DateTime(2026, 6, 1), [balance]),
      (DateTime(2026, 6, 7), [squat]),
    ]);
    await pumpProgramScreen(tester, history);

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(find.text('Verloop'), findsNothing);
  });
}
