import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Over Chiron'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 16),
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset('assets/icon.png', width: 96, height: 96),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              'Chiron',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'Versie 1.0.0',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 24),
          Text(
            'Chiron is een persoonlijke revalidatie-app die je helpt je fysiotherapieprogramma\'s bij te houden en consequent uit te voeren.',
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: AppColors.textSecondary, height: 1.6),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          _InfoRow(icon: Icons.healing_outlined, label: 'Gemaakt voor revalidatie en herstel'),
          _InfoRow(icon: Icons.schedule_outlined, label: 'Persoonlijk trainingsschema'),
          _InfoRow(icon: Icons.trending_up_outlined, label: 'Progressieve belasting bijhouden'),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}
