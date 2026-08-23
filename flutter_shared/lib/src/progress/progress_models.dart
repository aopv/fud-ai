import 'package:flutter/foundation.dart';

enum ProgressRange {
  week('1W'),
  month('1M'),
  threeMonths('3M'),
  sixMonths('6M'),
  year('1Y'),
  allTime('ALL');

  const ProgressRange(this.label);
  final String label;

  String get channelValue => switch (this) {
    week => 'week',
    month => 'month',
    threeMonths => 'threeMonths',
    sixMonths => 'sixMonths',
    year => 'year',
    allTime => 'allTime',
  };
}

@immutable
class TrendSample {
  const TrendSample({required this.timestampMs, required this.value});

  factory TrendSample.fromJson(Map<Object?, Object?> json) => TrendSample(
    timestampMs: (json['timestampMs'] as num).toInt(),
    value: (json['value'] as num).toDouble(),
  );

  final int timestampMs;
  final double value;

  DateTime get date => DateTime.fromMillisecondsSinceEpoch(timestampMs);
}

@immutable
class CalorieSample {
  const CalorieSample({required this.timestampMs, required this.calories});

  factory CalorieSample.fromJson(Map<Object?, Object?> json) => CalorieSample(
    timestampMs: (json['timestampMs'] as num).toInt(),
    calories: (json['calories'] as num).toInt(),
  );

  final int timestampMs;
  final int calories;

  DateTime get date => DateTime.fromMillisecondsSinceEpoch(timestampMs);
}

@immutable
class ProgressStrings {
  const ProgressStrings({required this.values});

  factory ProgressStrings.fromJson(Object? raw) {
    final map = (raw as Map<Object?, Object?>?) ?? const {};
    return ProgressStrings(
      values: map.map((key, value) => MapEntry('$key', '$value')),
    );
  }

  final Map<String, String> values;

  String operator [](String key) => values[key] ?? _fallback[key] ?? key;

  static const _fallback = <String, String>{
    'eyebrow': 'YOUR DATA',
    'title': 'PROGRESS',
    'subtitle': 'Trends, targets, and training history',
    'weight': 'WEIGHT',
    'bodyFat': 'BODY FAT',
    'logWeight': 'LOG WEIGHT',
    'logBodyFat': 'LOG BODY FAT',
    'current': 'CURRENT',
    'goal': 'GOAL',
    'netChange': 'NET CHANGE',
    'average': 'AVERAGE',
    'emptyWeight': 'Log your first weight to see trends',
    'emptyBodyFat': 'Log your first body-fat reading to see trends',
    'weightHistory': 'WEIGHT HISTORY',
    'bodyFatHistory': 'BODY FAT HISTORY',
    'workoutHistory': 'WORKOUT HISTORY',
    'entries': 'entries',
    'entry': 'entry',
    'tapToView': 'tap to view or delete',
    'calories': 'CALORIES',
    'averagePrefix': 'AVG',
    'noFood': 'No food logged yet',
    'macroAverages': 'MACRO AVERAGES',
    'protein': 'PROTEIN',
    'carbs': 'CARBS',
    'fat': 'FAT',
  };
}

@immutable
class ProgressSnapshot {
  const ProgressSnapshot({
    required this.range,
    required this.weightUnit,
    required this.weightEntries,
    required this.bodyFatEntries,
    required this.dailyCalories,
    required this.currentWeight,
    required this.goalWeight,
    required this.currentBodyFat,
    required this.goalBodyFat,
    required this.showsBodyFat,
    required this.weightHistoryCount,
    required this.bodyFatHistoryCount,
    required this.workoutHistoryCount,
    required this.calorieGoal,
    required this.averageProtein,
    required this.averageCarbs,
    required this.averageFat,
    required this.proteinGoal,
    required this.carbsGoal,
    required this.fatGoal,
    required this.strings,
    this.isDark,
    this.safeAreaTop = true,
    this.bottomContentInset = 0,
  });

  factory ProgressSnapshot.fromJson(Map<Object?, Object?> json) {
    List<TrendSample> trends(String key) =>
        ((json[key] as List<Object?>?) ?? const [])
            .cast<Map<Object?, Object?>>()
            .map(TrendSample.fromJson)
            .toList(growable: false);
    final selectedRange = ProgressRange.values.firstWhere(
      (item) => item.channelValue == json['range'],
      orElse: () => ProgressRange.week,
    );
    return ProgressSnapshot(
      range: selectedRange,
      weightUnit: json['weightUnit'] as String? ?? 'lbs',
      weightEntries: trends('weightEntries'),
      bodyFatEntries: trends('bodyFatEntries'),
      dailyCalories: ((json['dailyCalories'] as List<Object?>?) ?? const [])
          .cast<Map<Object?, Object?>>()
          .map(CalorieSample.fromJson)
          .toList(growable: false),
      currentWeight: (json['currentWeight'] as num?)?.toDouble(),
      goalWeight: (json['goalWeight'] as num?)?.toDouble(),
      currentBodyFat: (json['currentBodyFat'] as num?)?.toDouble(),
      goalBodyFat: (json['goalBodyFat'] as num?)?.toDouble(),
      showsBodyFat: json['showsBodyFat'] as bool? ?? false,
      weightHistoryCount: (json['weightHistoryCount'] as num?)?.toInt() ?? 0,
      bodyFatHistoryCount: (json['bodyFatHistoryCount'] as num?)?.toInt() ?? 0,
      workoutHistoryCount: (json['workoutHistoryCount'] as num?)?.toInt() ?? 0,
      calorieGoal: (json['calorieGoal'] as num?)?.toInt() ?? 0,
      averageProtein: (json['averageProtein'] as num?)?.toDouble() ?? 0,
      averageCarbs: (json['averageCarbs'] as num?)?.toDouble() ?? 0,
      averageFat: (json['averageFat'] as num?)?.toDouble() ?? 0,
      proteinGoal: (json['proteinGoal'] as num?)?.toInt() ?? 0,
      carbsGoal: (json['carbsGoal'] as num?)?.toInt() ?? 0,
      fatGoal: (json['fatGoal'] as num?)?.toInt() ?? 0,
      strings: ProgressStrings.fromJson(json['strings']),
      isDark: json['isDark'] as bool?,
      safeAreaTop: json['safeAreaTop'] as bool? ?? true,
      bottomContentInset: (json['bottomContentInset'] as num?)?.toDouble() ?? 0,
    );
  }

  final ProgressRange range;
  final String weightUnit;
  final List<TrendSample> weightEntries;
  final List<TrendSample> bodyFatEntries;
  final List<CalorieSample> dailyCalories;
  final double? currentWeight;
  final double? goalWeight;
  final double? currentBodyFat;
  final double? goalBodyFat;
  final bool showsBodyFat;
  final int weightHistoryCount;
  final int bodyFatHistoryCount;
  final int workoutHistoryCount;
  final int calorieGoal;
  final double averageProtein;
  final double averageCarbs;
  final double averageFat;
  final int proteinGoal;
  final int carbsGoal;
  final int fatGoal;
  final ProgressStrings strings;
  final bool? isDark;
  final bool safeAreaTop;
  final double bottomContentInset;
}
