import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fud_ai_shared/src/coach/coach_screen.dart';
import 'package:fud_ai_shared/src/home/home_screen.dart';
import 'package:fud_ai_shared/src/settings/settings_screen.dart';
import 'package:fud_ai_shared/src/workouts/workouts_screen.dart';

Future<Object?> _perform(
  String action, {
  Map<String, Object?> arguments = const {},
}) async => null;

Widget _host(Widget child) => MaterialApp(home: Material(child: child));

void main() {
  testWidgets('renders the shared Home page', (tester) async {
    await tester.pumpWidget(
      _host(
        SharedHomeScreen(
          perform: _perform,
          snapshot: const {
            'title': 'Today',
            'dateLabel': 'Monday, August 24',
            'calorieGoal': 2000,
            'weekDays': [
              {
                'date': '2026-08-24',
                'weekday': 'M',
                'day': 24,
                'selected': true,
              },
            ],
            'mealGroups': <Object?>[],
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('TODAY'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'routes the shared Add Food chooser to the requested capability',
    (tester) async {
      String? action;
      Map<String, Object?>? capturedArguments;
      await tester.pumpWidget(
        _host(
          SharedHomeScreen(
            perform: (nextAction, {arguments = const {}}) async {
              action = nextAction;
              capturedArguments = arguments;
              return null;
            },
            snapshot: const {
              'title': 'Today',
              'date': '2026-08-24',
              'dateLabel': 'Monday, August 24',
              'calorieGoal': 2000,
              'weekDays': <Object?>[],
              'mealGroups': <Object?>[],
            },
          ),
        ),
      );
      await tester.dragUntilVisible(
        find.text('ADD FOOD'),
        find.byType(Scrollable).first,
        const Offset(0, -500),
      );
      await tester.tap(find.text('ADD FOOD'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('PHOTO & SCAN'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CAMERA'));
      await tester.pumpAndSettle();

      expect(action, 'home.quickAction');
      expect(capturedArguments, {'quickAction': 'CAMERA'});
    },
  );

  testWidgets('renders Coach, Settings, and Workouts shared pages', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        SharedCoachScreen(
          snapshot: const {'messages': <Object?>[], 'suggestions': <Object?>[]},
          perform: _perform,
        ),
      ),
    );
    expect(find.text('AI COACH'), findsOneWidget);

    await tester.pumpWidget(
      _host(
        SharedSettingsScreen(
          snapshot: const {
            'sections': [
              {
                'title': 'Profile',
                'rows': [
                  {'id': 'profile', 'title': 'Profile'},
                ],
              },
            ],
          },
          perform: _perform,
        ),
      ),
    );
    expect(find.text('SETTINGS'), findsOneWidget);
    expect(find.text('PROFILE'), findsWidgets);

    await tester.pumpWidget(
      _host(
        SharedWorkoutsScreen(
          snapshot: const {'mode': 'log', 'exercises': <Object?>[]},
          perform: _perform,
        ),
      ),
    );
    expect(find.text('WORKOUT LOG'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
