import 'package:flutter/material.dart';
import '../models/exercise.dart';
import '../models/program.dart';

final List<Program> programs = [_mobility, _strength];

final Program _mobility = Program(
  id: 'staging_mobility',
  name: 'Mobiliteit',
  description: 'Dagelijkse mobiliteitsoefeningen voor staging',
  color: const Color(0xFF00897B),
  emoji: '🧘',
  exercises: [
    const Exercise(
      id: 'stg_hip_90_90',
      name: 'Hip 90/90',
      description: 'Zit met beide knieën in een hoek van 90°. '
          'Houd de romp rechtop en voel een rek in de buitenste heup.',
      sets: 2,
      durationSeconds: 60,
      frequency: FrequencyType.daily,
      type: ExerciseType.timed,
      unilateral: true,
    ),
    const Exercise(
      id: 'stg_thoracic_rotation',
      name: 'Thoracale rotatie',
      description: 'Zit op je knieën. Leg een hand achter je hoofd en '
          'roteer de bovenrug zo ver mogelijk naar het plafond.',
      sets: 2,
      reps: 8,
      repBpm: 12,
      frequency: FrequencyType.daily,
      type: ExerciseType.reps,
      unilateral: true,
    ),
    const Exercise(
      id: 'stg_cat_cow',
      name: 'Cat-cow',
      description: 'Ga op handen en knieën. Wissel tussen een holle en '
          'ronde rug op het ritme van de ademhaling.',
      sets: 1,
      reps: 10,
      repBpm: 10,
      frequency: FrequencyType.daily,
      type: ExerciseType.reps,
    ),
    Exercise(
      id: 'stg_breathing',
      name: 'Diafragma ademhaling',
      description: 'Ademhalingsoefening voor ontspanning en activatie.',
      sets: 1,
      frequency: FrequencyType.daily,
      type: ExerciseType.steps,
      cycleCount: 5,
      steps: const [
        ExerciseStep(
          label: 'Inademen',
          instruction: 'Adem 4 tellen in door de neus. '
              'Voel de buik uitzetten, dan de ribben.',
        ),
        ExerciseStep(
          label: 'Uitademen',
          instruction: 'Adem 6 tellen uit door de mond. '
              'Laat de borst zakken, trek dan zachtjes de buik in.',
        ),
      ],
    ),
    const Exercise(
      id: 'stg_couch_stretch',
      name: 'Couch stretch',
      description: 'Knie op de grond tegen de muur, voet omhoog. '
          'Duw de heup naar voren voor een diepe quadriceps rek.',
      sets: 2,
      durationSeconds: 90,
      frequency: FrequencyType.nTimesPerWeek,
      type: ExerciseType.timed,
      unilateral: true,
    ),
  ],
);

final Program _strength = Program(
  id: 'staging_strength',
  name: 'Kracht',
  description: 'Krachttraining in vier progressieve fases',
  color: const Color(0xFF1565C0),
  emoji: '🏋️',
  phaseLabels: const {1: 'Wk 1–2', 2: 'Wk 3–4', 3: 'Wk 5–6', 4: 'Wk 7–8'},
  exercises: [
    const Exercise(
      id: 'stg_glute_bridge',
      name: 'Glute bridge',
      description: 'Lig op je rug, knieën gebogen. Duw de heupen omhoog '
          'en knijp de bilspieren samen bovenaan.',
      sets: 3,
      reps: 15,
      repBpm: 15,
      frequency: FrequencyType.daily,
      type: ExerciseType.reps,
      phase: 1,
    ),
    const Exercise(
      id: 'stg_rdl',
      name: 'Romanian deadlift',
      description: 'Sta rechtop met gewichten. Scharnier voorwaarts vanuit '
          'de heup, houd de rug recht en voel een rek in de hamstrings.',
      sets: 3,
      reps: 10,
      repBpm: 12,
      frequency: FrequencyType.nTimesPerWeek,
      type: ExerciseType.reps,
      hasWeight: true,
      phase: 2,
    ),
    const Exercise(
      id: 'stg_single_leg_rdl',
      name: 'Single leg RDL',
      description: 'Sta op één been. Scharnier voorwaarts en houd de '
          'vrije voet in lijn met de romp.',
      sets: 3,
      reps: 8,
      repBpm: 12,
      frequency: FrequencyType.nTimesPerWeek,
      type: ExerciseType.reps,
      hasWeight: true,
      unilateral: true,
      phase: 3,
    ),
    const Exercise(
      id: 'stg_bulgarian_split',
      name: 'Bulgarian split squat',
      description: 'Achterste voet op een bank. Zak gecontroleerd in een '
          'split squat tot de achterste knie bijna de grond raakt.',
      sets: 3,
      reps: 8,
      repBpm: 12,
      frequency: FrequencyType.nTimesPerWeek,
      type: ExerciseType.reps,
      hasWeight: true,
      unilateral: true,
      prepDurationSeconds: 20,
      phase: 4,
    ),
  ],
);
