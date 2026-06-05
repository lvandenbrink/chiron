import 'dart:async';
import 'package:flutter/widgets.dart';
import '../models/exercise.dart';
import '../models/program.dart';
import '../services/audio_service.dart';

enum WorkoutPhase { idle, preparing, exercise, rest, switchingSides, complete }

class WorkoutProvider extends ChangeNotifier with WidgetsBindingObserver {
  final AudioService _audioService;

  Program? _currentProgram;
  List<Exercise> _exercises = [];

  int _currentExerciseIndex = 0;
  int _currentSetIndex = 0;
  int _currentRepIndex = 0;
  int _currentStepIndex = 0;
  int _currentCycleIndex = 0;

  WorkoutPhase _phase = WorkoutPhase.idle;
  bool _isRunning = false;
  bool _isLeftSide = true;
  int _remainingSeconds = 0;
  int _prepSeconds = 0;

  Timer? _countdownTimer;
  Timer? _repCueTimer;
  bool _isDisposed = false;

  void Function(Exercise)? _onExerciseCompleted;
  void Function(List<Exercise>)? _onWorkoutCompleted;
  final List<Exercise> _completedExercises = [];

  static const int restDurationSeconds = 30;
  static const int prepDurationSeconds = 5;
  static const int firstPrepDurationSeconds = 10;
  static const int shortPrepDurationSeconds = 3;
  static const int switchSidesDurationSeconds = 3;

  WorkoutProvider({AudioService? audioService})
      : _audioService = audioService ?? AudioService() {
    WidgetsBinding.instance.addObserver(this);
  }

  // ── Getters ────────────────────────────────────────────────────────────────

  Program? get currentProgram => _currentProgram;
  List<Exercise> get exercises => _exercises;
  int get currentExerciseIndex => _currentExerciseIndex;
  int get currentSetIndex => _currentSetIndex;
  int get currentRepIndex => _currentRepIndex;
  int get currentStepIndex => _currentStepIndex;
  int get currentCycleIndex => _currentCycleIndex;
  WorkoutPhase get phase => _phase;
  bool get isRunning => _isRunning;
  bool get isLeftSide => _isLeftSide;
  bool get isPreparing => _phase == WorkoutPhase.preparing;
  bool get isResting => _phase == WorkoutPhase.rest;
  bool get isSwitchingSides => _phase == WorkoutPhase.switchingSides;
  bool get isComplete => _phase == WorkoutPhase.complete;
  bool get isRestAfterExercise => _phase == WorkoutPhase.rest && _currentSetIndex == 0;
  int get remainingSeconds => _remainingSeconds;
  int get prepSeconds => _prepSeconds;

  Exercise? get nextExercise =>
      _currentExerciseIndex + 1 < _exercises.length
          ? _exercises[_currentExerciseIndex + 1]
          : null;

  Exercise? get currentExercise =>
      _exercises.isNotEmpty && _currentExerciseIndex < _exercises.length
          ? _exercises[_currentExerciseIndex]
          : null;

  double get overallProgress {
    if (_exercises.isEmpty) return 0;
    final totalSets = _exercises.fold<int>(0, (sum, e) => sum + e.sets);
    if (totalSets == 0) return 0;
    int done = 0;
    for (int i = 0; i < _currentExerciseIndex; i++) {
      done += _exercises[i].sets;
    }
    done += _currentSetIndex;
    return done / totalSets;
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if ((state == AppLifecycleState.paused || state == AppLifecycleState.inactive) && _isRunning) {
      pauseTimer();
    } else if (state == AppLifecycleState.resumed &&
        _phase != WorkoutPhase.idle &&
        _phase != WorkoutPhase.complete) {
      resumeTimer();
    }
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  void startWorkout(
    Program program,
    Set<int> scheduledDays, {
    Exercise Function(Exercise)? applySettings,
    void Function(Exercise)? onExerciseCompleted,
    void Function(List<Exercise>)? onWorkoutCompleted,
    int? phase,
  }) {
    _onExerciseCompleted = onExerciseCompleted;
    _onWorkoutCompleted = onWorkoutCompleted;
    _completedExercises.clear();
    _currentProgram = program;
    var all = program.exercises;
    if (applySettings != null) all = all.map(applySettings).toList();
    _exercises = _filterForToday(all, scheduledDays, phase: phase);
    if (_exercises.isEmpty) _exercises = all;
    _beginWorkout();
  }

  void startSingleExercise(Exercise exercise,
      {void Function(Exercise)? onExerciseCompleted}) {
    _onExerciseCompleted = onExerciseCompleted;
    _onWorkoutCompleted = null;
    _completedExercises.clear();
    _currentProgram = null;
    _exercises = [exercise];
    _beginWorkout();
  }

  void pauseTimer() {
    _cancelTimers();
    _isRunning = false;
    notifyListeners();
  }

  void resumeTimer() {
    _isRunning = true;
    switch (_phase) {
      case WorkoutPhase.preparing:
        _runPrepCountdown();
      case WorkoutPhase.switchingSides:
        _runSideSwitchCountdown();
      case WorkoutPhase.rest:
        _runRestCountdown();
      case WorkoutPhase.exercise:
        final exercise = currentExercise;
        if (exercise?.type == ExerciseType.timed) {
          _startCountdown();
        } else if (exercise != null && exercise.type == ExerciseType.reps) {
          if (_currentRepIndex >= (exercise.reps ?? 0)) {
            _onSetDone();
          } else {
            _runRepTimer(exercise);
          }
        }
      default:
        break;
    }
    notifyListeners();
  }

  void togglePause() => _isRunning ? pauseTimer() : resumeTimer();

  void completeInstruction() => _onSetDone();

  void nextStep() {
    final exercise = currentExercise;
    if (exercise == null || exercise.steps == null) return;
    final totalCycles = exercise.cycleCount ?? 1;
    if (_currentStepIndex < exercise.steps!.length - 1) {
      _currentStepIndex++;
    } else {
      _currentStepIndex = 0;
      _currentCycleIndex++;
    }
    if (_currentCycleIndex >= totalCycles) {
      _onSetDone();
    } else {
      notifyListeners();
    }
  }

  void skipExercise() {
    _cancelTimers();
    final credit = _phase == WorkoutPhase.switchingSides;
    _advanceToNextExercise(completed: credit);
  }

  void skipRest() {
    _cancelTimers();
    _afterRest();
  }

  void skipPrep() {
    if (_phase != WorkoutPhase.preparing) return;
    _cancelTimers();
    _phase = WorkoutPhase.exercise;
    _audioService.playExerciseStart();
    _startExerciseTimer();
    notifyListeners();
  }

  void skipSideSwitch() {
    _cancelTimers();
    _initExerciseTimerValues();
    _phase = WorkoutPhase.exercise;
    _audioService.playExerciseStart();
    _startExerciseTimer();
    notifyListeners();
  }

  void resetWorkout() {
    _cancelTimers();
    _phase = WorkoutPhase.idle;
    _isRunning = false;
    _reset();
    _completedExercises.clear();
    _onWorkoutCompleted = null;
    notifyListeners();
  }

  void resetOnExerciseCompleted() => _onExerciseCompleted = null;

  // ── Workout flow ───────────────────────────────────────────────────────────

  void _beginWorkout() {
    _reset();
    _phase = WorkoutPhase.exercise;
    _isRunning = true;
    _cancelTimers();
    _startCurrentExercise();
    notifyListeners();
  }

  void _startCurrentExercise({bool afterRest = false}) {
    final exercise = currentExercise;
    if (exercise == null) return;
    _currentRepIndex = 0;
    _currentStepIndex = 0;
    _currentCycleIndex = 0;
    _isLeftSide = true;

    switch (exercise.type) {
      case ExerciseType.timed:
      case ExerciseType.reps:
        _startPrep(afterRest: afterRest);
      case ExerciseType.instruction:
      case ExerciseType.steps:
        _phase = WorkoutPhase.exercise;
    }
  }

  void _onSetDone() {
    final exercise = currentExercise;
    if (exercise == null) return;

    if (exercise.unilateral && _isLeftSide) {
      _isLeftSide = false;
      _startSideSwitch();
      return;
    }

    _isLeftSide = true;
    if (_currentSetIndex < exercise.sets - 1) {
      _currentSetIndex++;
      _startRestTimer();
    } else {
      _currentSetIndex = 0;
      _advanceToNextExercise(completed: true);
    }
  }

  void _advanceToNextExercise({required bool completed}) {
    final exercise = currentExercise;
    if (completed && exercise != null) {
      _onExerciseCompleted?.call(exercise);
      _completedExercises.add(exercise);
    }
    if (_currentExerciseIndex < _exercises.length - 1) {
      _currentExerciseIndex++;
      _currentSetIndex = 0;
      _isRunning = true;
      final restAfter = exercise?.restAfterExerciseSeconds;
      if (restAfter != null && restAfter > 0) {
        _startRestTimer(duration: restAfter);
      } else {
        _phase = WorkoutPhase.exercise;
        _startCurrentExercise();
      }
      notifyListeners();
    } else {
      _phase = WorkoutPhase.complete;
      _isRunning = false;
      _cancelTimers();
      _onWorkoutCompleted?.call(List.unmodifiable(_completedExercises));
      notifyListeners();
    }
  }

  void _afterRest() {
    _phase = WorkoutPhase.exercise;
    _isRunning = true;
    _startCurrentExercise(afterRest: true);
    notifyListeners();
  }

  // ── Timer phases ───────────────────────────────────────────────────────────

  void _startPrep({bool afterRest = false}) {
    _phase = WorkoutPhase.preparing;
    final exercise = currentExercise;
    if (afterRest) {
      _prepSeconds = shortPrepDurationSeconds;
    } else if (_currentExerciseIndex == 0 && _currentSetIndex == 0) {
      _prepSeconds = (exercise?.prepDurationSeconds ?? firstPrepDurationSeconds)
          .clamp(1, firstPrepDurationSeconds);
    } else {
      _prepSeconds = exercise?.prepDurationSeconds ??
          (exercise?.hasWeight == true ? prepDurationSeconds : shortPrepDurationSeconds);
    }
    _cancelTimers();
    _runPrepCountdown();
    notifyListeners();
  }

  // Starts the prep countdown using the current _prepSeconds value.
  // Called by _startPrep (initial start) and resumeTimer (resume after pause).
  void _runPrepCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (_prepSeconds > 1) {
        _prepSeconds--;
        notifyListeners();
      } else {
        t.cancel();
        final prepExercise = currentExercise;
        _initExerciseTimerValues();
        _phase = WorkoutPhase.exercise;
        notifyListeners();
        await _audioService.playExerciseStart();
        if (_isDisposed || currentExercise != prepExercise || _phase != WorkoutPhase.exercise) return;
        _startExerciseTimer();
        notifyListeners();
      }
    });
  }

  void _startSideSwitch() {
    _phase = WorkoutPhase.switchingSides;
    _prepSeconds = switchSidesDurationSeconds;
    _cancelTimers();
    _runSideSwitchCountdown();
    notifyListeners();
  }

  void _runSideSwitchCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (_prepSeconds > 1) {
        _prepSeconds--;
        notifyListeners();
      } else {
        t.cancel();
        _initExerciseTimerValues();
        _phase = WorkoutPhase.exercise;
        notifyListeners();
        await _audioService.playExerciseStart();
        if (_isDisposed || _phase != WorkoutPhase.exercise) return;
        _startExerciseTimer();
        notifyListeners();
      }
    });
  }

  void _startRestTimer({int duration = restDurationSeconds}) {
    _phase = WorkoutPhase.rest;
    _remainingSeconds = duration;
    _cancelTimers();
    _runRestCountdown();
    notifyListeners();
  }

  void _runRestCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
        notifyListeners();
      } else {
        t.cancel();
        _afterRest();
      }
    });
  }

  // ── Exercise timers ────────────────────────────────────────────────────────

  // Sets the initial display values before the start sound so the UI shows
  // the correct starting state immediately when the phase changes to exercise.
  void _initExerciseTimerValues() {
    final exercise = currentExercise;
    if (exercise == null) return;
    if (exercise.type == ExerciseType.timed) {
      _remainingSeconds = exercise.durationSeconds ?? 30;
    } else if (exercise.type == ExerciseType.reps) {
      _currentRepIndex = 0;
    }
  }

  void _startExerciseTimer() {
    final exercise = currentExercise;
    if (exercise == null) return;
    switch (exercise.type) {
      case ExerciseType.timed:
        _remainingSeconds = exercise.durationSeconds ?? 30;
        _startCountdown();
      case ExerciseType.reps:
        if ((exercise.reps ?? 0) <= 0) return;
        _currentRepIndex = 0;
        _runRepTimer(exercise);
      default:
        break;
    }
  }

  void _startCountdown() {
    _cancelTimers();
    _isRunning = true;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
        notifyListeners();
      } else {
        t.cancel();
        await _audioService.playSetComplete();
        if (_isDisposed) return;
        _onSetDone();
      }
    });
  }

  void _runRepTimer(Exercise exercise) {
    _cancelTimers();
    final intervalMs = (60000 / exercise.repBpm).round();
    final totalReps = exercise.reps ?? 0;
    _repCueTimer = Timer.periodic(Duration(milliseconds: intervalMs), (t) async {
      _currentRepIndex++;
      notifyListeners();
      if (_currentRepIndex >= totalReps) {
        t.cancel();
        await _audioService.playSetComplete();
        if (_isDisposed) return;
        await Future.delayed(const Duration(seconds: 1));
        if (_isDisposed) return;
        _onSetDone();
        notifyListeners();
      } else {
        _audioService.playTick();
      }
    });
    notifyListeners();
  }

  void _cancelTimers() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _repCueTimer?.cancel();
    _repCueTimer = null;
  }

  // ── Utilities ──────────────────────────────────────────────────────────────

  List<Exercise> _filterForToday(List<Exercise> all, Set<int> days, {int? phase}) =>
      all
          .where((e) =>
              (e.frequency != FrequencyType.nTimesPerWeek ||
                  days.contains(DateTime.now().weekday)) &&
              (phase == null || e.phase == null || e.phase == phase))
          .toList();

  void _reset() {
    _currentExerciseIndex = 0;
    _currentSetIndex = 0;
    _currentRepIndex = 0;
    _currentStepIndex = 0;
    _currentCycleIndex = 0;
    _isLeftSide = true;
  }

  /// Estimates total workout duration in seconds.
  /// Timed/reps: actual duration + prep per set. Instruction/steps: 60 s per set.
  /// All types include rest between sets.
  static int estimatedDurationSeconds(List<Exercise> exercises) {
    int total = 0;
    for (final e in exercises) {
      final bool hasPrepPhase =
          e.type == ExerciseType.timed || e.type == ExerciseType.reps;
      final int exerciseDuration = switch (e.type) {
        ExerciseType.timed => e.durationSeconds ?? 30,
        ExerciseType.reps => ((e.reps ?? 0) * 60.0 / e.repBpm).round(),
        _ => 60,
      };
      final int prepPerSet = hasPrepPhase ? prepDurationSeconds : 0;
      final int sideCount = e.unilateral ? 2 : 1;
      final int sideSwitchPerSet = e.unilateral ? switchSidesDurationSeconds : 0;
      total += e.sets * (prepPerSet + exerciseDuration * sideCount + sideSwitchPerSet);
      total += (e.sets - 1) * restDurationSeconds;
      total += e.restAfterExerciseSeconds ?? 0;
    }
    return total;
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _cancelTimers();
    _audioService.dispose();
    super.dispose();
  }
}
