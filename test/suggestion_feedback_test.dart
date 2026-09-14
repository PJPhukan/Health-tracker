import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_tracker/database/database_helper.dart';
import 'package:health_tracker/database/health_repository.dart';
import 'package:health_tracker/models/models.dart';
import 'package:health_tracker/models/suggestion_feedback.dart';
import 'package:health_tracker/models/user_profile.dart';
import 'package:health_tracker/providers/health_provider.dart';
import 'package:health_tracker/services/gemini_service.dart';
import 'package:health_tracker/services/toast_center.dart';
import 'package:health_tracker/widgets/suggestion_feedback_row.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late DatabaseHelper helper;
  late HealthRepository repo;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    databaseFactory = databaseFactoryFfi;
    helper = DatabaseHelper.instance;
    repo = HealthRepository(helper: helper);
    final db = await helper.database;
    for (final t in DatabaseHelper.syncedCollections.keys) {
      await db.delete(t);
    }
  });

  group('Stage 1 - Suggestion Feedback Database & Prompt Integration', () {

    test('insert and count negative feedback for missing ingredients', () async {
      await repo.insertSuggestionFeedback(const SuggestionFeedback(
        suggestionId: 's1',
        rating: 'negative',
        reason: 'Missing ingredients',
        timestamp: '2026-09-13T10:00:00',
      ));
      await repo.insertSuggestionFeedback(const SuggestionFeedback(
        suggestionId: 's2',
        rating: 'negative',
        reason: 'Missing ingredients',
        timestamp: '2026-09-13T11:00:00',
      ));
      await repo.insertSuggestionFeedback(const SuggestionFeedback(
        suggestionId: 's3',
        rating: 'positive',
        timestamp: '2026-09-13T12:00:00',
      ));

      expect(await repo.getNegativeFeedbackCountForReason('Missing ingredients'), 2);

      await repo.insertSuggestionFeedback(const SuggestionFeedback(
        suggestionId: 's4',
        rating: 'negative',
        reason: 'Missing ingredients',
        timestamp: '2026-09-13T13:00:00',
      ));

      expect(await repo.getNegativeFeedbackCountForReason('Missing ingredients'), 3);
    });

    test('Gemini prompt adds missing ingredients warning when flag is true', () {
      final ai = GeminiService();
      final summary = DailySummary(
        date: '2026-09-13',
        meals: [],
        workouts: [],
      );
      final pantry = [
        PantryItem(id: 1, itemName: 'Eggs', quantity: '4', isLow: false, lastUpdated: '2026-09-13'),
      ];
      const goals = HealthGoals.starter;

      final normalPrompt = ai.buildPrompt(summary, pantry, goals, missingIngredientsWarning: false);
      expect(normalPrompt.contains('Previously the user said suggestions had missing ingredients'), isFalse);

      final warningPrompt = ai.buildPrompt(summary, pantry, goals, missingIngredientsWarning: true);
      expect(warningPrompt.contains('Previously the user said suggestions had missing ingredients — make sure every item is in their pantry list'), isTrue);
    });
  });

  group('Stage 1 - SuggestionFeedbackRow Widget', () {
    testWidgets('Tapping thumbs up records positive feedback and shows toast', (tester) async {
      bool positiveCallbackFired = false;

      final repo = HealthRepository(helper: DatabaseHelper.instance);
      final provider = HealthProvider(repo: repo);

      await tester.pumpWidget(
        MaterialApp(
          scaffoldMessengerKey: ToastCenter.scaffoldMessengerKey,
          home: Scaffold(
            body: ChangeNotifierProvider<HealthProvider>.value(
              value: provider,
              child: SuggestionFeedbackRow(
                suggestionId: 's_test_1',
                onPositiveFeedback: () {
                  positiveCallbackFired = true;
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('Was this helpful?'), findsOneWidget);
      expect(find.byIcon(Icons.thumb_up_alt_outlined), findsOneWidget);
      expect(find.byIcon(Icons.thumb_down_alt_outlined), findsOneWidget);

      await tester.tap(find.byIcon(Icons.thumb_up_alt_outlined));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(positiveCallbackFired, isTrue);
      expect(find.text('Glad it helped!'), findsOneWidget);
    });

    testWidgets('Tapping thumbs down opens bottom sheet with reason chips and submits', (tester) async {
      final repo = HealthRepository(helper: DatabaseHelper.instance);
      final provider = HealthProvider(repo: repo);

      await tester.pumpWidget(
        MaterialApp(
          scaffoldMessengerKey: ToastCenter.scaffoldMessengerKey,
          home: Scaffold(
            body: ChangeNotifierProvider<HealthProvider>.value(
              value: provider,
              child: const SuggestionFeedbackRow(
                suggestionId: 's_test_2',
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.thumb_down_alt_outlined));
      await tester.pumpAndSettle();

      expect(find.text('How can we improve this suggestion?'), findsOneWidget);
      expect(find.text('Missing ingredients'), findsOneWidget);
      expect(find.text('Doesn\'t match my goal'), findsOneWidget);
      expect(find.text('Already ate this'), findsOneWidget);
      expect(find.text('Other'), findsOneWidget);
      expect(find.text('Tell us more (optional)'), findsOneWidget);

      // Select 'Doesn\'t match my goal'
      await tester.tap(find.text('Doesn\'t match my goal'));
      await tester.pump();

      // Tap send feedback
      await tester.tap(find.text('Send feedback'));
      await tester.pump();
      await tester.pumpAndSettle();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Thanks for the feedback!'), findsOneWidget);
    });
  });
}
