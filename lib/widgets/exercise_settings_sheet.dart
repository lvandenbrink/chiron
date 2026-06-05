import 'package:flutter/material.dart';
import '../models/exercise.dart';
import '../models/progression.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';

class ExerciseSettingsSheet extends StatefulWidget {
  final Exercise exercise;
  final SettingsProvider settings;

  const ExerciseSettingsSheet(
      {super.key, required this.exercise, required this.settings});

  @override
  State<ExerciseSettingsSheet> createState() => _ExerciseSettingsSheetState();
}

class _ExerciseSettingsSheetState extends State<ExerciseSettingsSheet> {
  late double _weight;
  late double _repBpm;
  late ExerciseSettings _es;

  @override
  void initState() {
    super.initState();
    _es = widget.settings.settingsFor(widget.exercise.id);
    _weight = _es.weight;
    _repBpm = widget.settings.repBpmFor(widget.exercise).toDouble();
  }

  Exercise get ex => widget.exercise;

  Future<void> _save() async {
    await widget.settings.updateSettings(ex.id, _es.copyWith(weight: _weight));
    await widget.settings.setRepBpm(ex.id, _repBpm.round());
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Text(ex.name, style: Theme.of(context).textTheme.titleLarge),
          Text(
            'Oefening instellingen',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 28),

          // ── Weight ──────────────────────────────────────────────────────
          if (ex.hasWeight) ...[
            _SectionTitle('Gewicht'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _StepButton(
                  icon: Icons.remove,
                  onTap: () => setState(() {
                    _weight = (_weight - 0.5).clamp(0, 200);
                    _save();
                  }),
                  onLongPress: () => setState(() {
                    _weight = (_weight - 2.5).clamp(0, 200);
                    _save();
                  }),
                ),
                const SizedBox(width: 24),
                Column(
                  children: [
                    Text(
                      _weight == 0
                          ? 'Geen\ngewicht'
                          : '${_weight % 1 == 0 ? _weight.toInt() : _weight}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: _weight == 0 ? 20 : 52,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        height: 1.1,
                      ),
                    ),
                    if (_weight > 0)
                      const Text('kg',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 15)),
                  ],
                ),
                const SizedBox(width: 24),
                _StepButton(
                  icon: Icons.add,
                  onTap: () => setState(() {
                    _weight = (_weight + 0.5).clamp(0, 200);
                    _save();
                  }),
                  onLongPress: () => setState(() {
                    _weight = (_weight + 2.5).clamp(0, 200);
                    _save();
                  }),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                'Tik: ±0.5 kg  ·  Houd vast: ±2.5 kg',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 28),
            const Divider(),
            const SizedBox(height: 20),
          ],

          // ── Rep BPM ──────────────────────────────────────────────────────
          if (ex.type == ExerciseType.reps) ...[
            _SectionTitle('Tempo'),
            const SizedBox(height: 12),
            Center(
              child: Column(
                children: [
                  Text(
                    '${_repBpm.round()}',
                    style: const TextStyle(
                        fontSize: 52,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        height: 1),
                  ),
                  Text(
                    'bpm  ·  ${(60 / _repBpm).toStringAsFixed(1)}s per rep',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 15),
                  ),
                ],
              ),
            ),
            Slider(
              value: _repBpm,
              min: 5,
              max: 60,
              divisions: 55,
              label: '${_repBpm.round()} bpm',
              onChanged: (v) => setState(() => _repBpm = v),
              onChangeEnd: (v) {
                _repBpm = v;
                _save();
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('5 bpm',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
                Text('60 bpm',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 28),
          ],

          // ── Progressive overload ─────────────────────────────────────────
          if (ex.hasWeight) ...[
            if (ex.type == ExerciseType.reps) ...[
              const Divider(),
              const SizedBox(height: 20),
            ],
            Row(
              children: [
                Expanded(
                    child: _SectionTitle('Progressieve overbelasting')),
                Switch(
                  value: _es.progression.enabled,
                  onChanged: (v) => setState(() {
                    _es = _es.copyWith(
                        progression:
                            _es.progression.copyWith(enabled: v));
                    _save();
                  }),
                ),
              ],
            ),
            if (_es.progression.enabled) ...[
              const SizedBox(height: 16),

              // Type toggle
              SegmentedButton<OverloadType>(
                segments: const [
                  ButtonSegment(
                      value: OverloadType.weight,
                      icon: Icon(Icons.fitness_center, size: 16),
                      label: Text('Gewicht')),
                  ButtonSegment(
                      value: OverloadType.reps,
                      icon: Icon(Icons.repeat, size: 16),
                      label: Text('Herhalingen')),
                ],
                selected: {_es.progression.type},
                onSelectionChanged: (s) => setState(() {
                  _es = _es.copyWith(
                      progression:
                          _es.progression.copyWith(type: s.first));
                  _save();
                }),
              ),
              const SizedBox(height: 20),

              // Increment
              if (_es.progression.type == OverloadType.weight) ...[
                _Label('Verhoging per stap'),
                Slider(
                  value: _es.progression.weightIncrement,
                  min: 0.5,
                  max: 10,
                  divisions: 19,
                  label: '+${_es.progression.weightIncrement} kg',
                  onChanged: (v) => setState(() {
                    _es = _es.copyWith(
                        progression: _es.progression
                            .copyWith(weightIncrement: v));
                  }),
                  onChangeEnd: (v) {
                    _es = _es.copyWith(
                        progression:
                            _es.progression.copyWith(weightIncrement: v));
                    _save();
                  },
                ),
                Center(
                  child: Text('+${_es.progression.weightIncrement} kg per stap',
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600)),
                ),
              ] else ...[
                _Label('Verhoging per stap'),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: _es.progression.repIncrement > 1
                          ? () => setState(() {
                                _es = _es.copyWith(
                                    progression: _es.progression.copyWith(
                                        repIncrement:
                                            _es.progression.repIncrement -
                                                1));
                                _save();
                              })
                          : null,
                    ),
                    Text('+${_es.progression.repIncrement} reps',
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary)),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: _es.progression.repIncrement < 10
                          ? () => setState(() {
                                _es = _es.copyWith(
                                    progression: _es.progression.copyWith(
                                        repIncrement:
                                            _es.progression.repIncrement +
                                                1));
                                _save();
                              })
                          : null,
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),

              // Schedule
              _Label('Schema'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Elke ${_es.progression.scheduleValue} '
                          '${_es.progression.scheduleUnit == ScheduleUnit.workouts ? 'workouts' : 'weken'}',
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 15),
                        ),
                        Slider(
                          value:
                              _es.progression.scheduleValue.toDouble(),
                          min: 1,
                          max: 12,
                          divisions: 11,
                          label: '${_es.progression.scheduleValue}',
                          onChanged: (v) => setState(() {
                            _es = _es.copyWith(
                                progression: _es.progression
                                    .copyWith(scheduleValue: v.round()));
                          }),
                          onChangeEnd: (v) {
                            _es = _es.copyWith(
                                progression: _es.progression
                                    .copyWith(scheduleValue: v.round()));
                            _save();
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SegmentedButton<ScheduleUnit>(
                    segments: const [
                      ButtonSegment(
                          value: ScheduleUnit.workouts,
                          label: Text('Workouts')),
                      ButtonSegment(
                          value: ScheduleUnit.weeks,
                          label: Text('Weken')),
                    ],
                    selected: {_es.progression.scheduleUnit},
                    onSelectionChanged: (s) => setState(() {
                      _es = _es.copyWith(
                          progression: _es.progression
                              .copyWith(scheduleUnit: s.first));
                      _save();
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Status
              _ProgressStatus(settings: _es, exercise: ex),
              const SizedBox(height: 16),

              // Manual trigger
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.trending_up, size: 18),
                      label: const Text('Verhoog nu'),
                      onPressed: () => setState(() {
                        _es = _es.applyProgression(ex.reps ?? 0);
                        _weight = _es.weight;
                        _save();
                      }),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.restart_alt, size: 18),
                    label: const Text('Reset'),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade400),
                    onPressed: () => setState(() {
                      _es = _es.copyWith(
                          completionCount: 0, lastProgressDate: null);
                      _save();
                    }),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _StepButton(
      {required this.icon,
      required this.onTap,
      required this.onLongPress});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          shape: BoxShape.circle,
          border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.3), width: 1.5),
        ),
        child: Icon(icon, color: AppColors.primary),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) => Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      );
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: AppColors.textSecondary, fontSize: 12),
      );
}

class _ProgressStatus extends StatelessWidget {
  final ExerciseSettings settings;
  final Exercise exercise;

  const _ProgressStatus(
      {required this.settings, required this.exercise});

  @override
  Widget build(BuildContext context) {
    final p = settings.progression;
    String statusText;

    if (p.scheduleUnit == ScheduleUnit.workouts) {
      final remaining = settings.workoutsUntilProgress();
      if (remaining == 0) {
        statusText = 'Klaar voor verhoging!';
      } else {
        statusText =
            'Nog $remaining workout${remaining == 1 ? '' : 's'} tot verhoging';
      }
    } else {
      if (settings.lastProgressDate == null) {
        statusText = 'Start een workout om de timer te beginnen';
      } else {
        final weeks =
            DateTime.now().difference(settings.lastProgressDate!).inDays /
                7.0;
        final remaining = p.scheduleValue - weeks;
        if (remaining <= 0) {
          statusText = 'Klaar voor verhoging!';
        } else {
          statusText =
              'Nog ${remaining.ceil()} week${remaining.ceil() == 1 ? '' : 'en'} tot verhoging';
        }
      }
    }

    final isReady = settings.shouldProgress(exercise.reps ?? 0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isReady
            ? Colors.green.withValues(alpha: 0.1)
            : AppColors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isReady
              ? Colors.green.withValues(alpha: 0.4)
              : AppColors.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isReady ? Icons.check_circle_outline : Icons.schedule,
            size: 16,
            color: isReady ? Colors.green : AppColors.primary,
          ),
          const SizedBox(width: 8),
          Text(
            statusText,
            style: TextStyle(
              color: isReady ? Colors.green.shade700 : AppColors.primary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
