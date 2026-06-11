import 'package:chiron/main.dart';
import 'package:chiron/providers/history_provider.dart';
import 'package:chiron/providers/settings_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChironApp(settings: SettingsProvider(), history: HistoryProvider()),
    );
    expect(find.text('Chiron'), findsOneWidget);
    expect(find.text('Demo programma'), findsOneWidget);
    expect(find.text('Fase programma'), findsOneWidget);
  });
}
