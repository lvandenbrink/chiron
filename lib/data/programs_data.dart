import '../models/program.dart';
import 'programs_example.dart' as example;
import 'programs_production.dart' as production;
import 'package:flutter/services.dart';

List<Program> get programs => switch (appFlavor) {
  'production' => production.programs,
  _ => example.programs,
};
