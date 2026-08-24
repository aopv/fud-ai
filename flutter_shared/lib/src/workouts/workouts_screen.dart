import 'package:flutter/material.dart';

import '../app/neo_components.dart';

class SharedWorkoutsScreen extends StatelessWidget {
  const SharedWorkoutsScreen({
    required this.snapshot,
    required this.perform,
    super.key,
  });

  final Map<Object?, Object?> snapshot;
  final Future<Object?> Function(
    String action, {
    Map<String, Object?> arguments,
  })
  perform;

  @override
  Widget build(BuildContext context) {
    final mode = snapshot['mode'] as String? ?? 'log';
    return NeoPage(
      children: [
        NeoHeader(
          eyebrow: mode == 'log' ? 'Train with intent' : 'Movement library',
          title: mode == 'log' ? 'Workout Log' : 'Exercises',
          subtitle: mode == 'log'
              ? 'Plan, perform, and review every set'
              : 'Find movements by muscle and equipment',
          icon: Icons.fitness_center,
          trailing: NeoIconTile(
            icon: mode == 'log' ? Icons.grid_view : Icons.edit_note,
            color: NeoColors.acid,
            onTap: () => perform('workouts.toggleMode'),
          ),
        ),
        const SizedBox(height: 14),
        if (mode == 'log')
          _WorkoutLog(snapshot: snapshot, perform: perform)
        else
          _ExerciseLibrary(snapshot: snapshot, perform: perform),
      ],
    );
  }
}

class _WorkoutLog extends StatelessWidget {
  const _WorkoutLog({required this.snapshot, required this.perform});
  final Map<Object?, Object?> snapshot;
  final Future<Object?> Function(
    String action, {
    Map<String, Object?> arguments,
  })
  perform;

  @override
  Widget build(BuildContext context) {
    final exercises = (snapshot['exercises'] as List<Object?>? ?? const [])
        .map((item) => Map<Object?, Object?>.from(item! as Map))
        .toList();
    return Column(
      children: [
        NeoFrame(
          color: NeoColors.cobalt,
          child: Row(
            children: [
              NeoIconTile(
                icon: Icons.chevron_left,
                color: Colors.black,
                size: 42,
                onTap: () => perform('workouts.previousDate'),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      (snapshot['dateTitle'] as String? ?? 'Today')
                          .toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      snapshot['dateSubtitle'] as String? ?? '',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              NeoIconTile(
                icon: Icons.chevron_right,
                color: Colors.black,
                size: 42,
                onTap: snapshot['canMoveForward'] as bool? ?? false
                    ? () => perform('workouts.nextDate')
                    : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _Stat(label: 'Exercises', value: '${exercises.length}'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Stat(
                label: 'Sets',
                value: '${snapshot['setCount'] ?? 0}',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Stat(
                label: 'Reps',
                value: '${snapshot['repCount'] ?? 0}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: NeoButton(
                label: 'Add Exercise',
                icon: Icons.add,
                onPressed: () => perform('workouts.addExercise'),
              ),
            ),
            const SizedBox(width: 8),
            NeoButton(
              label: 'Copy',
              compact: true,
              icon: Icons.copy,
              color: NeoColors.surface(context),
              onPressed: () => perform('workouts.copyDay'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (exercises.isEmpty)
          const NeoEmpty(
            text: 'No exercises planned. Add one to start your workout.',
            icon: Icons.fitness_center,
          )
        else
          ...exercises.expand(
            (exercise) => [
              _ExerciseLogCard(exercise: exercise, perform: perform),
              const SizedBox(height: 10),
            ],
          ),
        if (exercises.isNotEmpty) ...[
          NeoButton(
            label: snapshot['caloriesBurned'] == null
                ? 'Calculate Burn'
                : '${snapshot['caloriesBurned']} Kcal Burned',
            icon: Icons.local_fire_department,
            onPressed: snapshot['calculatingBurn'] as bool? ?? false
                ? null
                : () => perform('workouts.calculateBurn'),
          ),
        ],
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return NeoFrame(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: NeoColors.cobalt,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: NeoColors.muted(context),
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseLogCard extends StatelessWidget {
  const _ExerciseLogCard({required this.exercise, required this.perform});
  final Map<Object?, Object?> exercise;
  final Future<Object?> Function(
    String action, {
    Map<String, Object?> arguments,
  })
  perform;

  @override
  Widget build(BuildContext context) {
    final sets = (exercise['sets'] as List<Object?>? ?? const [])
        .map((item) => Map<Object?, Object?>.from(item! as Map))
        .toList();
    return NeoFrame(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          InkWell(
            onTap: () => perform(
              'workouts.openExercise',
              arguments: {'id': exercise['itemId'] as String? ?? ''},
            ),
            child: Container(
              color: NeoColors.acid,
              padding: const EdgeInsets.all(11),
              child: Row(
                children: [
                  const Icon(Icons.fitness_center, color: Colors.black),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      (exercise['name'] as String? ?? 'Exercise').toUpperCase(),
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.black),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              children: [
                Row(
                  children: [
                    const SizedBox(width: 28),
                    ...['WEIGHT', 'REPS', 'RPE'].map(
                      (label) => Expanded(
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: NeoColors.muted(context),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                ...sets.indexed.map((indexed) {
                  final set = indexed.$2;
                  return Padding(
                    padding: const EdgeInsets.only(top: 7),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 28,
                          child: Text(
                            '${indexed.$1 + 1}',
                            style: TextStyle(
                              color: NeoColors.cobalt,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        ...['weight', 'reps', 'rpe'].map(
                          (field) => Expanded(
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: NeoColors.ink(context),
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                '${set[field] ?? '—'}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: NeoColors.ink(context),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseLibrary extends StatelessWidget {
  const _ExerciseLibrary({required this.snapshot, required this.perform});
  final Map<Object?, Object?> snapshot;
  final Future<Object?> Function(
    String action, {
    Map<String, Object?> arguments,
  })
  perform;

  @override
  Widget build(BuildContext context) {
    final exercises =
        (snapshot['libraryExercises'] as List<Object?>? ?? const [])
            .map((item) => Map<Object?, Object?>.from(item! as Map))
            .toList();
    return Column(
      children: [
        NeoFrame(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: TextField(
            decoration: InputDecoration(
              border: InputBorder.none,
              icon: Icon(Icons.search, color: NeoColors.cobalt),
              hintText: 'Search exercises',
              suffixIcon: IconButton(
                onPressed: () => perform('workouts.openFilters'),
                icon: Icon(Icons.tune, color: NeoColors.ink(context)),
              ),
            ),
            onSubmitted: (value) =>
                perform('workouts.search', arguments: {'query': value}),
          ),
        ),
        const SizedBox(height: 10),
        if (exercises.isEmpty)
          const NeoEmpty(
            text: 'No exercises match the current filters.',
            icon: Icons.search_off,
          )
        else
          ...exercises.expand(
            (exercise) => [
              NeoFrame(
                onTap: () => perform(
                  'workouts.openLibraryExercise',
                  arguments: {'id': exercise['id'] as String? ?? ''},
                ),
                padding: const EdgeInsets.all(11),
                child: Row(
                  children: [
                    NeoIconTile(
                      icon: Icons.fitness_center,
                      color: exercise['saved'] as bool? ?? false
                          ? NeoColors.acid
                          : NeoColors.cobalt,
                      size: 46,
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (exercise['name'] as String? ?? '').toUpperCase(),
                            style: TextStyle(
                              color: NeoColors.ink(context),
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${exercise['primaryMuscle'] ?? ''} · ${exercise['equipment'] ?? ''}',
                            style: TextStyle(
                              color: NeoColors.muted(context),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: NeoColors.ink(context)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
      ],
    );
  }
}
