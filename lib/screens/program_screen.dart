import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/exercise.dart';
import '../models/program.dart';
import '../models/workout_log.dart';
import '../providers/history_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/workout_provider.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/exercise_card.dart';
import '../widgets/exercise_settings_sheet.dart';
import 'workout_screen.dart';

String _formatDuration(int seconds) {
  if (seconds <= 0) return '';
  final minutes = (seconds / 60).round();
  return minutes < 1 ? '<1 min' : '~$minutes min';
}

class ProgramScreen extends StatelessWidget {
  final Program program;

  const ProgramScreen({super.key, required this.program});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final scheduledDays = settings.scheduledDaysFor(program.id);
    final isScheduledDay = scheduledDays.contains(DateTime.now().weekday);
    final timesPerDay = settings.timesPerDayFor(program.id);

    final hasPhases = program.exercises.any((e) => e.phase != null);
    final selectedPhase = hasPhases ? settings.phaseFor(program.id) : null;

    final dailyExercises = hasPhases
        ? program.exercises
            .where((e) =>
                e.frequency == FrequencyType.daily &&
                e.phase == selectedPhase)
            .toList()
        : program.dailyExercises;
    final weekExercises = hasPhases
        ? program.exercises
            .where((e) =>
                e.frequency == FrequencyType.nTimesPerWeek &&
                e.phase == selectedPhase)
            .toList()
        : program.nTimesPerWeekExercises;

    return Scaffold(
      appBar: AppBar(
        title: Text(program.name),
        backgroundColor: program.color,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Trainingsschema',
            onPressed: () => _showSchedulePicker(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Program header
          Container(
            color: program.color,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Row(
              children: [
                Text(program.emoji,
                    style: const TextStyle(fontSize: 36)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    program.description,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 14, height: 1.4),
                  ),
                ),
              ],
            ),
          ),

          if (hasPhases)
            _PhaseSelector(
              program: program,
              selectedPhase: selectedPhase!,
              onPhaseSelected: (p) =>
                  context.read<SettingsProvider>().setPhase(program.id, p),
            ),
          if (weekExercises.isNotEmpty || timesPerDay > 1)
            _ScheduleRow(
              program: program,
              scheduledDays: scheduledDays,
              isScheduledDay: isScheduledDay,
              timesPerDay: timesPerDay,
              hasWeekExercises: weekExercises.isNotEmpty,
              onTap: () => _showSchedulePicker(context),
            ),

          // Exercise list
          Expanded(
            child: ListView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 100,
              ),
              children: [
                if (dailyExercises.isNotEmpty) ...[
                  _SectionHeader(
                    label: 'Dagelijks',
                    color: AppColors.daily,
                    icon: Icons.today,
                    count: dailyExercises.length,
                  ),
                  ...dailyExercises.map((e) => _card(context, e, settings)),
                ],
                if (weekExercises.isNotEmpty) ...[
                  _SectionHeader(
                    label: '${scheduledDays.length}× per week',
                    color: AppColors.nTimesPerWeek,
                    icon: Icons.calendar_view_week,
                    count: weekExercises.length,
                    subtitle: isScheduledDay ? null : 'Niet vandaag',
                  ),
                  ...weekExercises.map((e) => _card(context, e, settings,
                        dimmed: !isScheduledDay)),
                ],
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Builder(builder: (context) {
            final settings = context.watch<SettingsProvider>();
            final scheduledDays = settings.scheduledDaysFor(program.id);
            final today = DateTime.now().weekday;
            final hasPhases = program.exercises.any((e) => e.phase != null);
            final selectedPhase = hasPhases ? settings.phaseFor(program.id) : null;
            final todayExercises = program.exercises
                .where((e) =>
                    (e.frequency != FrequencyType.nTimesPerWeek ||
                        scheduledDays.contains(today)) &&
                    (selectedPhase == null ||
                        e.phase == null ||
                        e.phase == selectedPhase))
                .map(settings.withExerciseSettings)
                .toList();
            final duration = WorkoutProvider.estimatedDurationSeconds(todayExercises);
            final durationLabel = _formatDuration(duration);

            return ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: program.color,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: () => _startWorkout(context),
              icon: const Icon(Icons.play_arrow_rounded, size: 24),
              label: Text(
                durationLabel.isEmpty
                    ? 'Start workout'
                    : 'Start workout  ·  $durationLabel',
                style: AppTextStyles.actionButton,
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _card(
    BuildContext context,
    Exercise exercise,
    SettingsProvider settings, {
    bool dimmed = false,
  }) {
    final es = settings.settingsFor(exercise.id);
    return ExerciseCard(
      exercise: settings.withExerciseSettings(exercise),
      dimmed: dimmed,
      weight: exercise.hasWeight ? es.weight : null,
      exerciseSettings: es,
      onTap: () => _startSingle(context, exercise),
      onEdit: (exercise.hasWeight || exercise.type == ExerciseType.reps)
          ? () => _openSettings(context, exercise, settings)
          : null,
    );
  }

  void _startWorkout(BuildContext context) {
    final settings = context.read<SettingsProvider>();
    final history = context.read<HistoryProvider>();
    final hasPhases = program.exercises.any((e) => e.phase != null);
    context.read<WorkoutProvider>().startWorkout(
      program,
      settings.scheduledDaysFor(program.id),
      applySettings: settings.withExerciseSettings,
      phase: hasPhases ? settings.phaseFor(program.id) : null,
      onExerciseCompleted: (e) {
        settings.recordCompletion(e.id, e.reps ?? 0).catchError(
          (err) => debugPrint('recordCompletion failed: $err'),
        );
      },
      onWorkoutCompleted: (completedExercises) {
        final today = DateTime.now();
        final completionsToday = history
                .logsForDate(today)
                .where((l) => l.programId == program.id)
                .length +
            1; // +1 for the workout that just finished
        final todayScheduledDays = settings.scheduledDaysFor(program.id);
        final hasExercisesToday = program.dailyExercises.isNotEmpty ||
            (program.nTimesPerWeekExercises.isNotEmpty &&
                todayScheduledDays.contains(today.weekday));
        if (NotificationService.shouldSuppressNotificationToday(
          notificationsEnabled: settings.notificationsEnabledFor(program.id),
          hasExercisesToday: hasExercisesToday,
          timesPerDay: settings.timesPerDayFor(program.id),
          completionsToday: completionsToday,
        )) {
          NotificationService.instance.rescheduleFromTomorrow(
            id: NotificationService.notifId(program.id),
            title: program.name,
            body: 'Je hebt vandaag nog niet geoefend.',
            time: settings.notificationTimeFor(program.id),
          );
        }
        history.addLog(WorkoutLog(
          id: today.toIso8601String(),
          date: today,
          programId: program.id,
          programName: program.name,
          exercises: completedExercises.map((e) {
            final es = settings.settingsFor(e.id);
            return ExerciseLog.fromExercise(e, weight: es.weight);
          }).toList(),
        ));
      },
    );
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => const WorkoutScreen()));
  }

  void _showSchedulePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _SchedulePickerSheet(
        program: program,
        hasWeekExercises: program.nTimesPerWeekExercises.isNotEmpty,
      ),
    );
  }

  void _startSingle(BuildContext context, Exercise exercise) {
    final settings = context.read<SettingsProvider>();
    context.read<WorkoutProvider>().startSingleExercise(
      settings.withExerciseSettings(exercise),
      onExerciseCompleted: (e) {
        settings.recordCompletion(e.id, e.reps ?? 0).catchError(
          (err) => debugPrint('recordCompletion failed: $err'),
        );
      },
    );
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => const WorkoutScreen()));
  }

  void _openSettings(
      BuildContext context, Exercise exercise, SettingsProvider settings) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => ExerciseSettingsSheet(
        exercise: exercise,
        settings: settings,
      ),
    );
  }
}

class _PhaseSelector extends StatelessWidget {
  final Program program;
  final int selectedPhase;
  final void Function(int) onPhaseSelected;

  const _PhaseSelector({
    required this.program,
    required this.selectedPhase,
    required this.onPhaseSelected,
  });

  static const _fallbackLabels = {1: 'Wk 1–2', 2: 'Wk 3–4', 3: 'Wk 5–6', 4: 'Wk 7–8'};

  @override
  Widget build(BuildContext context) {
    final labels = program.phaseLabels ?? _fallbackLabels;
    return Container(
      color: program.color.withValues(alpha: 0.06),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SegmentedButton<int>(
        segments: [
          for (final entry in labels.entries)
            ButtonSegment(value: entry.key, label: Text(entry.value)),
        ],
        selected: {selectedPhase},
        onSelectionChanged: (s) => onPhaseSelected(s.first),
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: program.color,
          selectedForegroundColor: Colors.white,
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  final Program program;
  final Set<int> scheduledDays;
  final bool isScheduledDay;
  final int timesPerDay;
  final bool hasWeekExercises;
  final VoidCallback onTap;

  const _ScheduleRow({
    required this.program,
    required this.scheduledDays,
    required this.isScheduledDay,
    required this.timesPerDay,
    required this.hasWeekExercises,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const names = {1: 'ma', 2: 'di', 3: 'wo', 4: 'do', 5: 'vr', 6: 'za', 7: 'zo'};
    final dayLabel = (scheduledDays.toList()..sort())
        .map((d) => names[d]!)
        .join(' · ');

    final Color rowColor = hasWeekExercises && !isScheduledDay
        ? AppColors.nTimesPerWeek
        : program.color;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        color: rowColor.withValues(alpha: 0.08),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            if (hasWeekExercises) ...[
              Icon(Icons.calendar_today_outlined, size: 13, color: rowColor),
              const SizedBox(width: 6),
              Text(
                dayLabel,
                style: TextStyle(
                    color: rowColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
              if (hasWeekExercises && !isScheduledDay) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: rowColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'vandaag niet',
                    style: TextStyle(
                        color: rowColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Container(
                    width: 3,
                    height: 3,
                    decoration: BoxDecoration(
                        color: rowColor.withValues(alpha: 0.4),
                        shape: BoxShape.circle)),
              ),
            ],
            Icon(Icons.replay_rounded, size: 13, color: rowColor),
            const SizedBox(width: 6),
            Text(
              '$timesPerDay× per dag',
              style: TextStyle(
                  color: rowColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Icon(Icons.chevron_right, size: 16,
                color: rowColor.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}

class _SchedulePickerSheet extends StatelessWidget {
  final Program program;
  final bool hasWeekExercises;

  const _SchedulePickerSheet({
    required this.program,
    required this.hasWeekExercises,
  });

  static const _dayNames = ['Ma', 'Di', 'Wo', 'Do', 'Vr', 'Za', 'Zo'];

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final activeDays = settings.scheduledDaysFor(program.id);
    final timesPerDay = settings.timesPerDayFor(program.id);
    final today = DateTime.now().weekday;

    return DraggableScrollableSheet(
      initialChildSize: hasWeekExercises ? 0.72 : 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Text('Trainingsschema',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          Text(program.name,
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 24),

          // Times per day
          Text('Sessies per dag',
              style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 10),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 1, label: Text('1× per dag')),
              ButtonSegment(value: 2, label: Text('2× per dag')),
            ],
            selected: {timesPerDay},
            onSelectionChanged: (s) =>
                context.read<SettingsProvider>().setTimesPerDay(program.id, s.first),
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: program.color,
              selectedForegroundColor: Colors.white,
            ),
          ),

          // Notification section
          const SizedBox(height: 24),
          Text('Herinnering',
              style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Herinner mij'),
            subtitle: Text(
              'Melding als ik nog niet heb geoefend',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            activeThumbColor: program.color,
            activeTrackColor: program.color.withValues(alpha: 0.4),
            value: settings.notificationsEnabledFor(program.id),
            onChanged: (v) => context
                .read<SettingsProvider>()
                .setNotificationsEnabled(program.id, v, program.name),
          ),
          if (settings.notificationsEnabledFor(program.id))
            Builder(builder: (ctx) {
              final time = settings.notificationTimeFor(program.id);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.access_time, color: program.color),
                title: const Text('Tijdstip'),
                trailing: Text(
                  time.format(ctx),
                  style: TextStyle(
                      color: program.color, fontWeight: FontWeight.w600),
                ),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: ctx,
                    initialTime: time,
                  );
                  if (picked != null && ctx.mounted) {
                    ctx
                        .read<SettingsProvider>()
                        .setNotificationTime(program.id, picked, program.name);
                  }
                },
              );
            }),

          if (hasWeekExercises) ...[
            const SizedBox(height: 24),
            Text('Trainingsdagen',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5)),
            const SizedBox(height: 4),
            Text(
              'Op welke dagen de per-week oefeningen worden gedaan',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(7, (i) {
                final day = i + 1;
                final active = activeDays.contains(day);
                final isToday = day == today;
                return GestureDetector(
                  onTap: () => context
                      .read<SettingsProvider>()
                      .toggleProgramDay(program.id, day),
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: active
                              ? program.color
                              : program.color.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: active
                                ? program.color
                                : program.color.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            _dayNames[i],
                            style: TextStyle(
                              color: active ? Colors.white : program.color,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      if (isToday)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                              color: program.color, shape: BoxShape.circle),
                        )
                      else
                        const SizedBox(height: 9),
                    ],
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final int count;
  final String? subtitle;

  const _SectionHeader({
    required this.label,
    required this.color,
    required this.icon,
    required this.count,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: AppTextStyles.sectionHeader.copyWith(color: color),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('$count',
                style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
          if (subtitle != null) ...[
            const Spacer(),
            Text(subtitle!,
                style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ],
        ],
      ),
    );
  }
}
