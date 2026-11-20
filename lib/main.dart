import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'data/program_catalog.dart';
import 'providers/history_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/workout_provider.dart';
import 'screens/home_screen.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = SettingsProvider();
  final history = HistoryProvider();
  final (catalog, _, _, _) = await (
    ProgramCatalog.load(rootBundle),
    settings.load(),
    history.load(),
    NotificationService.instance.init(),
  ).wait;
  await NotificationService.instance.requestPermission();
  runApp(ChironApp(catalog: catalog, settings: settings, history: history));
}

class ChironApp extends StatelessWidget {
  final ProgramCatalog catalog;
  final SettingsProvider settings;
  final HistoryProvider history;
  const ChironApp({
    super.key,
    required this.catalog,
    required this.settings,
    required this.history,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider.value(value: catalog),
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: history),
        ChangeNotifierProvider(create: (_) => WorkoutProvider()),
      ],
      child: MaterialApp(
        title: 'Chiron',
        theme: AppTheme.theme,
        debugShowCheckedModeBanner: false,
        home: const HomeScreen(),
      ),
    );
  }
}
