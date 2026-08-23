import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fud_ai_shared/main.dart';
import 'package:fud_ai_shared/src/native/progress_channel.dart';
import 'package:fud_ai_shared/src/progress/progress_models.dart';

class _FakeProgressRepository implements ProgressRepository {
  ProgressRange lastRange = ProgressRange.week;
  String? lastAction;

  @override
  Future<ProgressSnapshot> load(ProgressRange range) async {
    lastRange = range;
    return ProgressSnapshot(
      range: range,
      weightUnit: 'lbs',
      weightEntries: const [
        TrendSample(timestampMs: 1787443200000, value: 166.2),
        TrendSample(timestampMs: 1787529600000, value: 165.8),
      ],
      bodyFatEntries: const [],
      dailyCalories: const [
        CalorieSample(timestampMs: 1787443200000, calories: 2010),
        CalorieSample(timestampMs: 1787529600000, calories: 1880),
      ],
      currentWeight: 165.8,
      goalWeight: 155,
      currentBodyFat: null,
      goalBodyFat: null,
      showsBodyFat: false,
      weightHistoryCount: 2,
      bodyFatHistoryCount: 0,
      workoutHistoryCount: 3,
      calorieGoal: 2200,
      averageProtein: 145.2,
      averageCarbs: 211.4,
      averageFat: 63.8,
      proteinGoal: 160,
      carbsGoal: 240,
      fatGoal: 70,
      strings: const ProgressStrings(values: {}),
    );
  }

  @override
  Future<void> perform(String action) async => lastAction = action;
}

void main() {
  testWidgets('renders the shared neo Progress screen and changes range', (
    tester,
  ) async {
    final repository = _FakeProgressRepository();
    await tester.pumpWidget(FudAiSharedApp(progressRepository: repository));
    await tester.pumpAndSettle();

    expect(find.text('PROGRESS'), findsOneWidget);
    expect(find.text('WEIGHT'), findsOneWidget);
    await tester.tap(find.text('LOG WEIGHT'));
    await tester.pumpAndSettle();
    expect(repository.lastAction, 'logWeight');
    final scrollable = find.descendant(
      of: find.byKey(const ValueKey('progress.scroll')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text('CALORIES'),
      300,
      scrollable: scrollable,
    );
    expect(find.text('CALORIES'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('MACRO AVERAGES'),
      300,
      scrollable: scrollable,
    );
    expect(find.text('MACRO AVERAGES'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('progress.range.month')),
      -300,
      scrollable: scrollable,
    );
    await tester.tap(find.byKey(const ValueKey('progress.range.month')));
    await tester.pumpAndSettle();
    expect(repository.lastRange, ProgressRange.month);
  });
}
