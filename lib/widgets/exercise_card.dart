import 'package:flutter/material.dart';
import '../models/exercise.dart';
import '../models/progression.dart';
import '../theme/app_theme.dart';

class ExerciseCard extends StatelessWidget {
  final Exercise exercise;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final bool dimmed;
  final double? weight;
  final ExerciseSettings? exerciseSettings;

  const ExerciseCard({
    super.key,
    required this.exercise,
    this.onTap,
    this.onEdit,
    this.dimmed = false,
    this.weight,
    this.exerciseSettings,
  });

  @override
  Widget build(BuildContext context) {
    final hasProgression = exerciseSettings?.progression.enabled == true;

    String meta = exercise.setsRepsLabel;
    if (exercise.hasWeight) {
      final w = weight ?? 0;
      final wLabel = w == 0
          ? 'geen gewicht'
          : '${w % 1 == 0 ? w.toInt() : w} kg';
      meta += ' · $wLabel';
    }
    if (hasProgression) meta += ' ↑';

    return Opacity(
      opacity: dimmed ? 0.45 : 1.0,
      child: Card(
        clipBehavior: Clip.hardEdge,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
            child: Row(
              children: [
                _TypeIcon(type: exercise.type),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(exercise.name,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 3),
                      Text(
                        meta,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (onEdit != null)
                  IconButton(
                    onPressed: onEdit,
                    icon: const Icon(Icons.tune_rounded),
                    color: AppColors.textSecondary,
                    iconSize: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeIcon extends StatelessWidget {
  final ExerciseType type;
  const _TypeIcon({required this.type});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (type) {
      ExerciseType.timed => (Icons.timer_outlined, AppColors.primary),
      ExerciseType.reps => (Icons.repeat, AppColors.primary),
      ExerciseType.steps =>
        (Icons.view_carousel_outlined, AppColors.primary),
      ExerciseType.metronome =>
        (Icons.music_note_outlined, AppColors.primary),
    };
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}
