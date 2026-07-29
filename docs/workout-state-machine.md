# Workout State Machine

```mermaid
stateDiagram-v2
    [*] --> idle

    idle --> preparing : startWorkout() / startSingleExercise()

    preparing --> exercise : countdown ends → playExerciseStart()\nskipPrep()

    exercise --> switchingSides : unilateral left side done
    exercise --> rest : set done, more sets remain\nexercise done + restAfterExercise
    exercise --> preparing : exercise done, no restAfterExercise\n→ next exercise
    exercise --> complete : last exercise done

    switchingSides --> exercise : countdown ends → playExerciseStart()\nskipSideSwitch()

    rest --> preparing : countdown ends\nskipRest()

    complete --> idle : resetWorkout()
    complete --> [*]

    note right of preparing
        isRunning=false pauses
        any timed state;
        resume restarts
        the active timer
    end note
```

## Transitions

| From | To | Condition |
|---|---|---|
| `idle` | `preparing` | workout started |
| `preparing` | `exercise` | countdown ends (fires `playExerciseStart`) or `skipPrep()` |
| `exercise` | `switchingSides` | unilateral, left side just finished |
| `switchingSides` | `exercise` | 3 s countdown ends (fires `playExerciseStart`) or `skipSideSwitch()` |
| `exercise` | `rest` | set done + more sets remain, **or** exercise done + `restAfterExerciseSeconds` set |
| `rest` | `preparing` | 30 s countdown ends or `skipRest()` |
| `exercise` | `preparing` | exercise done, no rest → next exercise's prep starts |
| `exercise` | `complete` | last exercise's last set done |
| `complete` | `idle` | `resetWorkout()` |

`playExerciseStart` fires on every `preparing → exercise` and `switchingSides → exercise` transition.
Pause/resume (`isRunning` flag) is orthogonal — it freezes any timed state without changing the phase.
