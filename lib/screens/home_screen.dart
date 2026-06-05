import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/programs_data.dart';
import '../models/exercise.dart';
import '../models/program.dart';
import '../providers/settings_provider.dart';
import '../providers/workout_provider.dart';
import '../theme/app_theme.dart';
import 'about_screen.dart';
import 'history_screen.dart';
import 'program_screen.dart';

String _formatDuration(int seconds) {
  if (seconds <= 0) return '';
  final minutes = (seconds / 60).round();
  return minutes < 1 ? '<1 min' : '~$minutes min';
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  List<Program> _orderedPrograms(List<String> order) {
    if (order.isEmpty) return programs;
    final map = {for (final p in programs) p.id: p};
    final result = order.map((id) => map[id]).whereType<Program>().toList();
    for (final p in programs) {
      if (!result.any((r) => r.id == p.id)) result.add(p);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final ordered = _orderedPrograms(settings.programOrder);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chiron'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'history') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HistoryScreen()),
                );
              } else if (value == 'about') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AboutScreen()),
                );
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'history',
                child: Row(
                  children: [
                    Icon(Icons.history_rounded, color: AppColors.textPrimary),
                    const SizedBox(width: 12),
                    const Text('Geschiedenis'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'about',
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.textPrimary),
                    const SizedBox(width: 12),
                    const Text('Over Chiron'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: ReorderableListView(
        buildDefaultDragHandles: false,
        padding: EdgeInsets.fromLTRB(
          16, 16, 16, MediaQuery.of(context).padding.bottom + 16,
        ),
        onReorderItem: (oldIndex, newIndex) {
          final reordered = List<String>.from(ordered.map((p) => p.id));
          final item = reordered.removeAt(oldIndex);
          reordered.insert(newIndex, item);
          context.read<SettingsProvider>().setProgramOrder(reordered);
        },
        children: [
          for (var i = 0; i < ordered.length; i++)
            ReorderableDelayedDragStartListener(
              key: ValueKey(ordered[i].id),
              index: i,
              child: _ProgramCard(program: ordered[i]),
            ),
        ],
      ),
    );
  }
}

class _ProgramCard extends StatelessWidget {
  final Program program;

  const _ProgramCard({required this.program});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openProgram(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: program.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(program.emoji,
                      style: const TextStyle(fontSize: 26)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      program.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      program.description,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    _CardMeta(program: program),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: AppColors.textSecondary.withValues(alpha: 0.4),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openProgram(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProgramScreen(program: program)),
    );
  }
}

class _CardMeta extends StatelessWidget {
  final Program program;

  const _CardMeta({required this.program});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final timesPerDay = settings.timesPerDayFor(program.id);

    final scheduledDays = settings.scheduledDaysFor(program.id);
    final today = DateTime.now().weekday;
    final todayExercises = program.exercises
        .where((e) =>
            e.frequency != FrequencyType.nTimesPerWeek ||
            scheduledDays.contains(today))
        .map(settings.withExerciseSettings)
        .toList();
    final duration = WorkoutProvider.estimatedDurationSeconds(todayExercises);
    final durationLabel = _formatDuration(duration);

    final tags = <String>[];
    if (program.dailyExercises.isNotEmpty) tags.add('Dagelijks');
    if (program.nTimesPerWeekExercises.isNotEmpty) tags.add('Per week');
    if (timesPerDay > 1) tags.add('$timesPerDay×/dag');

    return Row(
      children: [
        ...tags.map((t) => Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _Tag(label: t, color: program.color),
            )),
        if (durationLabel.isNotEmpty) ...[
          const Spacer(),
          Icon(Icons.timer_outlined, size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 3),
          Text(
            durationLabel,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;

  const _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}
