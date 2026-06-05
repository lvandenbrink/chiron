import 'package:flutter/material.dart';
import '../models/exercise.dart';
import '../theme/app_theme.dart';

class FrequencyBadge extends StatelessWidget {
  final FrequencyType frequency;

  const FrequencyBadge({super.key, required this.frequency});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (frequency) {
      FrequencyType.daily => (AppColors.daily, 'Dagelijks'),
      FrequencyType.nTimesPerWeek => (AppColors.nTimesPerWeek, 'Per week'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: color, letterSpacing: 0.3),
          ),
        ],
      ),
    );
  }
}
