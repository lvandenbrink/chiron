import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  await Future.wait([
    settings.load(),
    history.load(),
    NotificationService.instance.init(),
  ]);
  await NotificationService.instance.requestPermission();
  runApp(ChironApp(settings: settings, history: history));
}

class ChironApp extends StatelessWidget {
  final SettingsProvider settings;
  final HistoryProvider history;
  const ChironApp({super.key, required this.settings, required this.history});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
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
