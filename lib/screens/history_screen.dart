import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/programs_data.dart';
import '../models/program.dart';
import '../models/workout_log.dart';
import '../providers/history_provider.dart';
import '../theme/app_theme.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late int _year;
  late int _month;
  DateTime? _selectedDay;

  static const _maanden = [
    'Januari', 'Februari', 'Maart', 'April', 'Mei', 'Juni',
    'Juli', 'Augustus', 'September', 'Oktober', 'November', 'December',
  ];
  static const _dagHeaders = ['Ma', 'Di', 'Wo', 'Do', 'Vr', 'Za', 'Zo'];
  static const _dagNamen = [
    'Maandag', 'Dinsdag', 'Woensdag', 'Donderdag', 'Vrijdag', 'Zaterdag', 'Zondag',
  ];
  static const _maandNamen = [
    'januari', 'februari', 'maart', 'april', 'mei', 'juni',
    'juli', 'augustus', 'september', 'oktober', 'november', 'december',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
  }

  void _prevMonth() {
    setState(() {
      _selectedDay = null;
      if (_month == 1) {
        _month = 12;
        _year--;
      } else {
        _month--;
      }
    });
  }

  void _nextMonth() {
    setState(() {
      _selectedDay = null;
      if (_month == 12) {
        _month = 1;
        _year++;
      } else {
        _month++;
      }
    });
  }

  void _toggleDay(DateTime day) {
    setState(() {
      _selectedDay =
          (_selectedDay?.day == day.day && _selectedDay?.month == day.month)
              ? null
              : day;
    });
  }

  void _confirmClearAll(BuildContext context, HistoryProvider history) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Geschiedenis wissen?'),
        content: const Text('Alle workout gegevens worden verwijderd.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuleren'),
          ),
          TextButton(
            onPressed: () {
              history.clearAll();
              Navigator.pop(ctx);
              setState(() => _selectedDay = null);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Wissen'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${_dagNamen[d.weekday - 1]} ${d.day} ${_maandNamen[d.month - 1]}';

  String _formatTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  Program? _findProgram(String programId) {
    try {
      return programs.firstWhere((p) => p.id == programId);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final history = context.watch<HistoryProvider>();
    final monthLogs = history.logsForMonth(_year, _month);
    final displayLogs = _selectedDay != null
        ? history.logsForDate(_selectedDay!)
        : monthLogs;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Geschiedenis'),
        actions: [
          if (history.logs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Alles wissen',
              onPressed: () => _confirmClearAll(context, history),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, MediaQuery.of(context).padding.bottom + 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MonthNavigator(
              year: _year,
              month: _month,
              monthName: _maanden[_month - 1],
              onPrev: _prevMonth,
              onNext: _nextMonth,
            ),
            const SizedBox(height: 12),
            _CalendarGrid(
              year: _year,
              month: _month,
              dayHeaders: _dagHeaders,
              selectedDay: _selectedDay,
              hasWorkout: history.hasWorkoutOnDate,
              onDayTap: _toggleDay,
            ),
            const SizedBox(height: 24),
            if (_selectedDay != null)
              Text(
                _formatDate(_selectedDay!),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
              )
            else
              Text(
                '${_maanden[_month - 1]} $_year',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            const SizedBox(height: 12),
            if (displayLogs.isEmpty)
              _EmptyState(
                message: _selectedDay != null
                    ? 'Geen workouts op deze dag.'
                    : history.logs.isEmpty
                        ? 'Nog geen workouts geregistreerd.\nVoltooi een workout om je voortgang bij te houden.'
                        : 'Geen workouts in deze maand.',
              )
            else
              ...displayLogs.map((log) => Dismissible(
                    key: Key(log.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.delete_outline, color: Colors.red),
                    ),
                    onDismissed: (_) => history.removeLog(log.id),
                    child: _WorkoutCard(
                      log: log,
                      program: _findProgram(log.programId),
                      formatTime: _formatTime,
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}

// ── Month navigator ───────────────────────────────────────────────────────────

class _MonthNavigator extends StatelessWidget {
  final int year;
  final int month;
  final String monthName;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _MonthNavigator({
    required this.year,
    required this.month,
    required this.monthName,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isFuture = year > now.year || (year == now.year && month > now.month);
    return Row(
      children: [
        IconButton(
          onPressed: onPrev,
          icon: const Icon(Icons.chevron_left),
          visualDensity: VisualDensity.compact,
        ),
        Expanded(
          child: Text(
            '$monthName $year',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        IconButton(
          onPressed: isFuture ? null : onNext,
          icon: const Icon(Icons.chevron_right),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}

// ── Calendar grid ─────────────────────────────────────────────────────────────

class _CalendarGrid extends StatelessWidget {
  final int year;
  final int month;
  final List<String> dayHeaders;
  final DateTime? selectedDay;
  final bool Function(DateTime) hasWorkout;
  final void Function(DateTime) onDayTap;

  const _CalendarGrid({
    required this.year,
    required this.month,
    required this.dayHeaders,
    required this.selectedDay,
    required this.hasWorkout,
    required this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final startOffset = firstDay.weekday - 1; // Mon = 0
    final today = DateTime.now();

    return Column(
      children: [
        // Day-of-week headers
        Row(
          children: dayHeaders
              .map((h) => Expanded(
                    child: Text(
                      h,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 4),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            ...List.generate(startOffset, (_) => const SizedBox.shrink()),
            ...List.generate(daysInMonth, (i) {
              final day = i + 1;
              final date = DateTime(year, month, day);
              final isSelected = selectedDay?.day == day &&
                  selectedDay?.month == month &&
                  selectedDay?.year == year;
              final isToday = date.year == today.year &&
                  date.month == today.month &&
                  date.day == today.day;
              final workout = hasWorkout(date);
              return _DayCell(
                day: day,
                isSelected: isSelected,
                isToday: isToday,
                hasWorkout: workout,
                onTap: () => onDayTap(date),
              );
            }),
          ],
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  final int day;
  final bool isSelected;
  final bool isToday;
  final bool hasWorkout;
  final VoidCallback onTap;

  const _DayCell({
    required this.day,
    required this.isSelected,
    required this.isToday,
    required this.hasWorkout,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isSelected
        ? Colors.white
        : isToday
            ? AppColors.primary
            : AppColors.textPrimary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : null,
          shape: BoxShape.circle,
          border: isToday && !isSelected
              ? Border.all(color: AppColors.primary, width: 1.5)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$day',
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight:
                    isToday || isSelected ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
            SizedBox(
              height: 6,
              child: hasWorkout && !isSelected
                  ? Center(
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Workout card ──────────────────────────────────────────────────────────────

class _WorkoutCard extends StatelessWidget {
  final WorkoutLog log;
  final Program? program;
  final String Function(DateTime) formatTime;

  const _WorkoutCard({
    required this.log,
    required this.program,
    required this.formatTime,
  });

  @override
  Widget build(BuildContext context) {
    final color = program?.color ?? AppColors.primary;
    final emoji = program?.emoji ?? '💪';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(emoji,
                        style: const TextStyle(fontSize: 18)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        log.programName,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        formatTime(log.date),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${log.exercises.length} oef.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
            if (log.exercises.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              ...log.exercises.map((e) => _ExerciseRow(exercise: e, color: color)),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  final ExerciseLog exercise;
  final Color color;

  const _ExerciseRow({required this.exercise, required this.color});

  @override
  Widget build(BuildContext context) {
    final weightLabel = exercise.hasWeight
        ? (exercise.weight == 0
            ? 'geen gewicht'
            : '${exercise.weight % 1 == 0 ? exercise.weight.toInt() : exercise.weight} kg')
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(right: 10, top: 1),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              exercise.name,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            [exercise.label, weightLabel].whereType<String>().join(' · '),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.textSecondary, height: 1.6),
        ),
      ),
    );
  }
}
