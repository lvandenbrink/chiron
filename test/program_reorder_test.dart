import 'package:chiron/data/programs_example.dart' as example;
import 'package:chiron/providers/history_provider.dart';
import 'package:chiron/providers/settings_provider.dart';
import 'package:chiron/screens/program_screen.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _longPressDrag(
  WidgetTester tester,
  Offset start,
  Offset end,
) async {
  final drag = await tester.startGesture(start);
  await tester.pump(kLongPressTimeout + kPressTimeout);
  const steps = 10;
  for (var i = 1; i <= steps; i++) {
    await drag.moveTo(Offset.lerp(start, end, i / steps)!);
    await tester.pump(kPressTimeout);
  }
  await drag.up();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'long-pressing and dragging an exercise reorders it within its '
      'section and persists the new order', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final program = example.programs.firstWhere((p) => p.id == 'demo');
    final settings = SettingsProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider<HistoryProvider>.value(
              value: HistoryProvider()),
        ],
        child: MaterialApp(home: ProgramScreen(program: program)),
      ),
    );
    await tester.pumpAndSettle();

    // Daily exercises start in declaration order: Balance hold, Warm-up,
    // Breathing drill.
    expect(
      tester.getCenter(find.text('Balance hold')).dy <
          tester.getCenter(find.text('Breathing drill')).dy,
      isTrue,
    );

    await _longPressDrag(
      tester,
      tester.getCenter(find.text('Balance hold')),
      tester.getCenter(find.text('Warm-up')) + const Offset(0, 40),
    );

    // Balance hold swapped past Warm-up but stayed above Breathing drill.
    expect(
      tester.getCenter(find.text('Balance hold')).dy >
          tester.getCenter(find.text('Warm-up')).dy,
      isTrue,
    );
    expect(
      tester.getCenter(find.text('Balance hold')).dy <
          tester.getCenter(find.text('Breathing drill')).dy,
      isTrue,
    );
    expect(settings.exerciseOrderFor('demo'), [
      'demo_warmup',
      'demo_balance',
      'demo_breathing',
      'demo_squat',
      'demo_rdl',
    ]);
  });
}
