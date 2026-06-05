import 'package:flutter_test/flutter_test.dart';
import 'package:fysio_app/main.dart';
import 'package:fysio_app/providers/history_provider.dart';
import 'package:fysio_app/providers/settings_provider.dart';

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
