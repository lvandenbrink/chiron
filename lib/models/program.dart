import 'package:flutter/material.dart';
import 'exercise.dart';

class Program {
  final String id;
  final String name;
  final String description;
  final Color color;
  final String emoji;
  final List<Exercise> exercises;
  final Map<int, String>? phaseLabels;

  const Program({
    required this.id,
    required this.name,
    required this.description,
    required this.color,
    required this.emoji,
    required this.exercises,
    this.phaseLabels,
  });

  List<Exercise> get dailyExercises =>
      exercises.where((e) => e.frequency == FrequencyType.daily).toList();

  List<Exercise> get nTimesPerWeekExercises =>
      exercises.where((e) => e.frequency == FrequencyType.nTimesPerWeek).toList();

}
