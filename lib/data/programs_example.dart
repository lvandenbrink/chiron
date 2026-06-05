// programs_local_example.dart — CHECKED IN, safe to share.
//
// To use:
//   cp lib/data/programs_local_example.dart lib/data/programs_local.dart
//
// programs_local.dart is git-ignored so your programs stay private.
// This file documents every supported field and exercise type.

import 'package:flutter/material.dart';
import '../models/exercise.dart';
import '../models/program.dart';

final List<Program> programs = [_demo, _phases];

// ── Demo program — one exercise per type ─────────────────────────────────────

final Program _demo = Program(
  id: 'demo',                         // must be unique across all programs
  name: 'Demo programma',
  description: 'Shows every exercise type and feature',
  color: const Color(0xFF00897B),     // any Material color
  emoji: '💪',
  exercises: [

    // ── timed ─────────────────────────────────────────────────────────────────
    // Countdown timer. Use unilateral: true to run left side then right side.
    const Exercise(
      id: 'demo_balance',             // must be unique across all exercises
      name: 'Balance hold',
      description: 'Stand on one leg. Keep the hip level and gaze forward.',
      sets: 3,
      durationSeconds: 30,
      frequency: FrequencyType.daily,
      type: ExerciseType.timed,
      unilateral: true,               // app runs left → side switch → right
    ),

    // ── reps ──────────────────────────────────────────────────────────────────
    // Beep cues each rep. hasWeight: true enables weight tracking and
    // progressive overload (configure per-exercise in settings).
    const Exercise(
      id: 'demo_squat',
      name: 'Squat',
      description: 'Feet shoulder-width. Lower until thighs are parallel. '
          'Keep knees in line with feet.',
      sets: 3,
      reps: 12,
      repBpm: 15,          // beep interval in seconds
      frequency: FrequencyType.nTimesPerWeek,  // only on scheduled training days
      type: ExerciseType.reps,
      hasWeight: true,
      // prepDurationSeconds: 10,     // override the default 5 s prep countdown
      // restAfterExerciseSeconds: 60, // override the default 30 s rest
    ),

    // ── reps + unilateral ─────────────────────────────────────────────────────
    const Exercise(
      id: 'demo_rdl',
      name: 'Single leg RDL',
      description: 'Hinge forward on one leg. Keep the back straight.',
      sets: 2,
      reps: 10,
      repBpm: 15,
      frequency: FrequencyType.nTimesPerWeek,
      type: ExerciseType.reps,
      hasWeight: true,
      unilateral: true,
    ),

    // ── instruction ───────────────────────────────────────────────────────────
    // Full-screen description card. User reads it and taps "Klaar" when done.
    const Exercise(
      id: 'demo_warmup',
      name: 'Warm-up',
      description: 'March on the spot for 2 minutes, gradually picking up pace. '
          'Swing your arms naturally.',
      sets: 1,
      frequency: FrequencyType.daily,
      type: ExerciseType.instruction,
    ),

    // ── steps ─────────────────────────────────────────────────────────────────
    // Multi-step carousel. cycleCount repeats the full sequence N times.
    Exercise(
      id: 'demo_breathing',
      name: 'Breathing drill',
      description: 'Two-phase nasal breathing. Repeat 3 times.',
      sets: 1,
      frequency: FrequencyType.daily,
      type: ExerciseType.steps,
      cycleCount: 3,
      steps: const [
        ExerciseStep(
          label: 'Inhale',
          instruction: 'Breathe in slowly for 4 counts through the nose. '
              'Feel the belly expand first, then the chest.',
        ),
        ExerciseStep(
          label: 'Exhale',
          instruction: 'Breathe out for 6 counts through pursed lips. '
              'Let the chest fall, then gently draw the belly in.',
        ),
      ],
    ),

  ],
);

// ── Phase-based program ───────────────────────────────────────────────────────
// Assign phase: 1–4 to group exercises into two-week blocks.
// The program screen shows a Wk 1–2 / Wk 3–4 / Wk 5–6 / Wk 7–8 selector;
// only the exercises for the active phase are shown and included in the workout.

final Program _phases = Program(
  id: 'demo_phases',
  name: 'Fase programma',
  description: 'Progressive 8-week plan with four selectable phases',
  color: const Color(0xFF5C6BC0),
  emoji: '🌱',
  exercises: [
    const Exercise(
      id: 'ph1_stretch',
      name: 'Full-body stretch',
      description: 'Gentle mobilisation to start the program.',
      sets: 1,
      durationSeconds: 60,
      frequency: FrequencyType.daily,
      type: ExerciseType.timed,
      phase: 1,                       // visible when Wk 1–2 is selected
    ),
    const Exercise(
      id: 'ph2_hinge',
      name: 'Hip hinge',
      description: 'Bodyweight hinge focusing on posterior chain activation.',
      sets: 2,
      reps: 10,
      repBpm: 15,
      frequency: FrequencyType.daily,
      type: ExerciseType.reps,
      phase: 2,                       // visible when Wk 3–4 is selected
    ),
    const Exercise(
      id: 'ph3_rdl',
      name: 'Single leg RDL',
      description: 'Add a light dumbbell once the movement feels controlled.',
      sets: 2,
      reps: 8,
      repBpm: 15,
      frequency: FrequencyType.daily,
      type: ExerciseType.reps,
      hasWeight: true,
      unilateral: true,
      phase: 3,                       // visible when Wk 5–6 is selected
    ),
    const Exercise(
      id: 'ph4_press',
      name: 'Overhead press',
      description: 'Press dumbbells from shoulder height to full extension.',
      sets: 3,
      reps: 10,
      repBpm: 15,
      frequency: FrequencyType.nTimesPerWeek,
      type: ExerciseType.reps,
      hasWeight: true,
      phase: 4,                       // visible when Wk 7–8 is selected
    ),
  ],
);
