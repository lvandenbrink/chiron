import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/exercise.dart';
import '../providers/workout_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/circular_timer.dart';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  bool _pressHeld = false;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  void _onPointerDown(WorkoutProvider provider) {
    if (provider.isRunning) {
      provider.togglePause();
      setState(() => _pressHeld = true);
    }
  }

  void _onPointerUp(WorkoutProvider provider) {
    if (_pressHeld) {
      provider.togglePause();
      setState(() => _pressHeld = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WorkoutProvider>(
      builder: (context, provider, _) {
        if (provider.isComplete) return const _CompleteScreen();
        if (provider.isResting) return _RestScreen(provider: provider);
        if (provider.isSwitchingSides) return _SideSwitchScreen(provider: provider);
        if (provider.isPreparing) {
          return _PrepScreen(
            provider: provider,
            onExit: () => _confirmExit(context, provider),
            pressHeld: _pressHeld,
            onPointerDown: () => _onPointerDown(provider),
            onPointerUp: () => _onPointerUp(provider),
          );
        }

        final exercise = provider.currentExercise;
        if (exercise == null) return const _CompleteScreen();

        final supportsHold = exercise.type == ExerciseType.timed ||
            exercise.type == ExerciseType.reps;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text(exercise.name),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => _confirmExit(context, provider),
            ),
          ),
          body: Column(
            children: [
              LinearProgressIndicator(
                value: provider.overallProgress,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.primary),
                minHeight: 4,
              ),
              Expanded(
                child: supportsHold
                    ? Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: (_) => _onPointerDown(provider),
                        onPointerUp: (_) => _onPointerUp(provider),
                        onPointerCancel: (_) => _onPointerUp(provider),
                        child: _TimedRepsLayout(
                          provider: provider,
                          exercise: exercise,
                          pressHeld: _pressHeld,
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _SetProgressIndicator(
                              currentSet: provider.currentSetIndex + 1,
                              totalSets: exercise.sets,
                              side: exercise.unilateral
                                  ? (provider.isLeftSide ? 'Links' : 'Rechts')
                                  : null,
                            ),
                            const SizedBox(height: 32),
                            switch (exercise.type) {
                              ExerciseType.instruction =>
                                _InstructionExerciseContent(
                                    exercise: exercise, provider: provider),
                              ExerciseType.steps => _StepsExerciseContent(
                                  exercise: exercise, provider: provider),
                              _ => const SizedBox.shrink(),
                            },
                          ],
                        ),
                      ),
              ),
              _BottomControls(provider: provider),
            ],
          ),
        );
      },
    );
  }

  void _confirmExit(BuildContext context, WorkoutProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Workout stoppen?'),
        content: const Text('Je voortgang gaat verloren als je nu stopt.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Doorgaan'),
          ),
          TextButton(
            onPressed: () {
              provider.resetWorkout();
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Stoppen'),
          ),
        ],
      ),
    );
  }
}

// ── Preparation screen ───────────────────────────────────────────────────────

class _PrepScreen extends StatelessWidget {
  final WorkoutProvider provider;
  final VoidCallback onExit;
  final bool pressHeld;
  final VoidCallback? onPointerDown;
  final VoidCallback? onPointerUp;

  const _PrepScreen({
    required this.provider,
    required this.onExit,
    this.pressHeld = false,
    this.onPointerDown,
    this.onPointerUp,
  });

  @override
  Widget build(BuildContext context) {
    final exercise = provider.currentExercise;
    if (exercise == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(exercise.name),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: onExit,
        ),
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: provider.overallProgress,
            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
            valueColor:
                const AlwaysStoppedAnimation<Color>(AppColors.primary),
            minHeight: 4,
          ),
          Expanded(
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: onPointerDown != null ? (_) => onPointerDown!() : null,
              onPointerUp: onPointerUp != null ? (_) => onPointerUp!() : null,
              onPointerCancel: onPointerUp != null ? (_) => onPointerUp!() : null,
              child: _TimedRepsLayout(
              provider: provider,
              exercise: exercise,
              pressHeld: pressHeld,
              hintText: pressHeld ? 'Laat los om verder te gaan' : 'Kom in positie',
              mainContent: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 28,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '${provider.prepSeconds}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 80,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),          // _TimedRepsLayout
            ),          // Listener
          ),            // Expanded
          Container(
            color: AppColors.surface,
            padding: EdgeInsets.fromLTRB(
                16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        context.read<WorkoutProvider>().skipExercise(),
                    child: const Text('Overslaan'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () =>
                        context.read<WorkoutProvider>().skipPrep(),
                    child: const Text('Begin nu'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Side switch screen ────────────────────────────────────────────────────────

class _SideSwitchScreen extends StatelessWidget {
  final WorkoutProvider provider;
  const _SideSwitchScreen({required this.provider});

  @override
  Widget build(BuildContext context) {
    final exercise = provider.currentExercise;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              Text(
                'Wissel van kant',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              if (exercise != null) ...[
                const SizedBox(height: 6),
                Text(
                  exercise.name,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ],
              const SizedBox(height: 12),
              const _SideBadge(side: 'Rechts'),
              const Spacer(),
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 28,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '${provider.prepSeconds}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 60,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () =>
                      context.read<WorkoutProvider>().skipSideSwitch(),
                  child: const Text('Wissel nu'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Rest screen ───────────────────────────────────────────────────────────────

class _RestScreen extends StatelessWidget {
  final WorkoutProvider provider;
  const _RestScreen({required this.provider});

  @override
  Widget build(BuildContext context) {
    final exercise = provider.currentExercise;
    if (exercise == null) return const SizedBox.shrink();

    final hintText = provider.isRestAfterExercise
        ? 'Volgende oefening begint automatisch'
        : 'Volgende set begint automatisch';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(exercise.name),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: provider.overallProgress,
            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            minHeight: 4,
          ),
          Expanded(
            child: _TimedRepsLayout(
              provider: provider,
              exercise: exercise,
              pressHeld: false,
              mainContent: CircularTimer(
                remainingSeconds: provider.remainingSeconds,
                totalSeconds: WorkoutProvider.restDurationSeconds,
                size: 220,
              ),
              hintText: hintText,
            ),
          ),
          Container(
            color: AppColors.surface,
            padding: EdgeInsets.fromLTRB(
                16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: provider.skipRest,
                    child: const Text('Sla rust over'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: provider.togglePause,
                    icon: Icon(
                      provider.isRunning
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      size: 20,
                    ),
                    label: Text(provider.isRunning ? 'Pauzeer' : 'Hervat'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared timed/reps layout ──────────────────────────────────────────────────
//
// Used by both _PrepScreen and the active exercise scaffold so the circle
// always appears at the same Y position when transitioning between phases.

class _TimedRepsLayout extends StatelessWidget {
  final WorkoutProvider provider;
  final Exercise exercise;
  final bool pressHeld;
  final Widget? mainContent; // overrides the auto-resolved circle for prep
  final String? hintText; // shown below the circle (overrides auto-resolved hint)

  const _TimedRepsLayout({
    required this.provider,
    required this.exercise,
    required this.pressHeld,
    this.mainContent,
    this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    final circle = mainContent ?? _resolveCircle();
    final Widget? hint = _resolveHint(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _SetProgressIndicator(
            currentSet: provider.currentSetIndex + 1,
            totalSets: exercise.sets,
            side: exercise.unilateral
                ? (provider.isLeftSide ? 'Links' : 'Rechts')
                : null,
          ),
          const Spacer(),
          circle,
          // Fixed-height hint slot: keeps circle Y consistent across all phases.
          SizedBox(
            height: 56,
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: hint ?? const SizedBox.shrink(),
              ),
            ),
          ),
          if (exercise.description != null)
            _DescriptionCard(description: exercise.description!),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _resolveCircle() {
    if (exercise.type == ExerciseType.timed) {
      return CircularTimer(
        remainingSeconds: provider.remainingSeconds,
        totalSeconds: exercise.durationSeconds ?? 30,
        size: 220,
      );
    }
    // reps
    final total = exercise.reps ?? 0;
    final done = provider.currentRepIndex;
    return Container(
      width: 220,
      height: 220,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withValues(alpha: 0.08),
        border:
            Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 3),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$done',
            style: const TextStyle(
              fontSize: 76,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
              height: 1,
            ),
          ),
          Text(
            'van $total',
            style: const TextStyle(fontSize: 17, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget? _resolveHint(BuildContext context) {
    if (hintText != null) {
      return Text(
        hintText!,
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: AppColors.textSecondary),
      );
    }
    if (exercise.type == ExerciseType.reps) {
      return _BpmBadge(bpm: exercise.repBpm);
    }
    return Text(
      pressHeld ? 'Laat los om verder te gaan' : 'Houd ingedrukt om te pauzeren',
      style: Theme.of(context)
          .textTheme
          .bodySmall
          ?.copyWith(color: AppColors.textSecondary),
    );
  }
}

class _BpmBadge extends StatelessWidget {
  final int bpm;
  const _BpmBadge({required this.bpm});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.music_note_outlined, size: 17, color: AppColors.primary),
          const SizedBox(width: 7),
          Text('$bpm bpm', style: AppTextStyles.cueBadge),
        ],
      ),
    );
  }
}

// ── Instruction / steps exercise ─────────────────────────────────────────────

// ── Instruction exercise ──────────────────────────────────────────────────────

class _InstructionExerciseContent extends StatelessWidget {
  final Exercise exercise;
  final WorkoutProvider provider;
  const _InstructionExerciseContent(
      {required this.exercise, required this.provider});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            exercise.description ?? exercise.name,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
          ),
        ),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: provider.completeInstruction,
            child: const Text('Klaar'),
          ),
        ),
      ],
    );
  }
}

// ── Steps exercise ────────────────────────────────────────────────────────────

class _StepsExerciseContent extends StatelessWidget {
  final Exercise exercise;
  final WorkoutProvider provider;
  const _StepsExerciseContent(
      {required this.exercise, required this.provider});

  @override
  Widget build(BuildContext context) {
    final steps = exercise.steps ?? [];
    if (steps.isEmpty) return const SizedBox.shrink();

    final step = steps[provider.currentStepIndex];
    final totalCycles = exercise.cycleCount ?? 1;
    final cycle = provider.currentCycleIndex + 1;
    final isLastStep = provider.currentStepIndex == steps.length - 1;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Cyclus $cycle van $totalCycles',
            style: AppTextStyles.chipLabel.copyWith(color: AppColors.primary),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Stap ${step.label}',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            step.instruction,
            textAlign: TextAlign.center,
            style:
                Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(steps.length, (i) {
            final active = i == provider.currentStepIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: active ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: active
                    ? AppColors.primary
                    : AppColors.primary.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: provider.nextStep,
            child: Text(isLastStep && cycle >= totalCycles
                ? 'Voltooien'
                : isLastStep
                    ? 'Volgende cyclus'
                    : 'Volgende stap'),
          ),
        ),
      ],
    );
  }
}

// ── Complete screen ───────────────────────────────────────────────────────────

class _CompleteScreen extends StatelessWidget {
  const _CompleteScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_outline,
                  color: Colors.white, size: 88),
              const SizedBox(height: 24),
              const Text(
                'Workout voltooid!',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(
                'Geweldig gedaan! Je hebt alle\noefeningen voltooid.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 17,
                    height: 1.5),
              ),
              const SizedBox(height: 64),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 48, vertical: 16),
                  textStyle: AppTextStyles.actionButton,
                ),
                onPressed: () {
                  context.read<WorkoutProvider>().resetWorkout();
                  Navigator.of(context).popUntil((r) => r.isFirst);
                },
                child: const Text('Terug naar home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _SetProgressIndicator extends StatelessWidget {
  final int currentSet;
  final int totalSets;
  final String? side;
  const _SetProgressIndicator({
    required this.currentSet,
    required this.totalSets,
    this.side,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Set $currentSet van $totalSets',
            style: AppTextStyles.chipLabel.copyWith(color: AppColors.primary),
          ),
        ),
        if (side != null) ...[
          const SizedBox(height: 8),
          _SideBadge(side: side!),
        ],
      ],
    );
  }
}

class _SideBadge extends StatelessWidget {
  final String side;
  const _SideBadge({required this.side});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        side,
        style: AppTextStyles.sideBadge,
      ),
    );
  }
}

class _DescriptionCard extends StatelessWidget {
  final String description;
  const _DescriptionCard({required this.description});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        description,
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: AppColors.textSecondary, height: 1.6),
      ),
    );
  }
}

class _BottomControls extends StatelessWidget {
  final WorkoutProvider provider;
  const _BottomControls({required this.provider});

  @override
  Widget build(BuildContext context) {
    final exercise = provider.currentExercise;
    final showPause = exercise != null &&
        (exercise.type == ExerciseType.timed ||
            exercise.type == ExerciseType.reps) &&
        !provider.isPreparing;

    return Container(
      color: AppColors.surface,
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: provider.skipExercise,
              icon: const Icon(Icons.skip_next, size: 20),
              label: const Text('Oefening overslaan'),
            ),
          ),
          if (showPause) ...[
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: provider.togglePause,
                icon: Icon(
                  provider.isRunning
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  size: 22,
                ),
                label: Text(provider.isRunning ? 'Pauzeer' : 'Hervat'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
