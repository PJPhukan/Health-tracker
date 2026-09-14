import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import '../providers/health_provider.dart';
import '../screens/suggestion_screen.dart';
import '../services/guest_service.dart';
import '../theme/app_theme.dart';
import '../widgets/guest_gate_dialog.dart';

class TutorialService {
  TutorialService._();
  static final TutorialService instance = TutorialService._();

  static const String _prefKey = 'has_seen_tutorial';

  Future<bool> hasSeenTutorial() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(_prefKey) ?? false;
  }

  Future<void> markTutorialSeen() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_prefKey, true);
  }

  @visibleForTesting
  Future<void> resetForTesting() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_prefKey);
  }

  Future<void> showTutorialIfNeeded({
    required BuildContext context,
    required GlobalKey suggestionKey,
    required GlobalKey pantryKey,
    required GlobalKey logKey,
    required GlobalKey progressKey,
  }) async {
    if (await hasSeenTutorial()) return;
    if (!context.mounted) return;

    final targets = <TargetFocus>[
      TargetFocus(
        identify: "step_suggestion",
        keyTarget: suggestionKey,
        shape: ShapeLightFocus.RRect,
        radius: 28,
        enableTargetTab: true,
        enableOverlayTab: true,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) => TutorialCard(
              title: "Get Suggestion",
              message: "Tap here to get a meal suggestion based on your pantry and goal",
              stepLabel: "1 of 4",
              isLast: false,
              onNext: () => controller.next(),
              onSkip: () => controller.skip(),
            ),
          ),
        ],
      ),
      TargetFocus(
        identify: "step_pantry",
        keyTarget: pantryKey,
        shape: ShapeLightFocus.Circle,
        enableTargetTab: true,
        enableOverlayTab: true,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) => TutorialCard(
              title: "Pantry",
              message: "Keep your pantry updated for accurate suggestions",
              stepLabel: "2 of 4",
              isLast: false,
              onNext: () => controller.next(),
              onSkip: () => controller.skip(),
              onBack: () => controller.previous(),
            ),
          ),
        ],
      ),
      TargetFocus(
        identify: "step_log",
        keyTarget: logKey,
        shape: ShapeLightFocus.Circle,
        enableTargetTab: true,
        enableOverlayTab: true,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) => TutorialCard(
              title: "Log Entry",
              message: "Log meals, workouts, sleep and steps to track your progress",
              stepLabel: "3 of 4",
              isLast: false,
              onNext: () => controller.next(),
              onSkip: () => controller.skip(),
              onBack: () => controller.previous(),
            ),
          ),
        ],
      ),
      TargetFocus(
        identify: "step_progress",
        keyTarget: progressKey,
        shape: ShapeLightFocus.Circle,
        enableTargetTab: true,
        enableOverlayTab: true,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) => TutorialCard(
              title: "Progress",
              message: "Watch your streaks and charts build up over time",
              stepLabel: "4 of 4",
              isLast: true,
              onNext: () => controller.next(),
              onSkip: () => controller.skip(),
              onBack: () => controller.previous(),
            ),
          ),
        ],
      ),
    ];

    late final TutorialCoachMark tutorial;
    tutorial = TutorialCoachMark(
      targets: targets,
      colorShadow: AppColors.tealDeep,
      textSkip: "Skip",
      paddingFocus: 8,
      opacityShadow: 0.85,
      hideSkip: true, // We have a dedicated Skip button in our custom card
      onClickTarget: (target) {
        if (target.identify == "step_suggestion") {
          markTutorialSeen();
          tutorial.finish();
          _onSuggestionTapped(context);
        } else if (target.identify == "step_progress") {
          markTutorialSeen();
          tutorial.finish();
        } else {
          tutorial.next();
        }
      },
      onClickOverlay: (target) {
        tutorial.next();
      },
      onFinish: () => markTutorialSeen(),
      onSkip: () {
        markTutorialSeen();
        return true;
      },
    );

    tutorial.show(context: context);
  }

  static void _onSuggestionTapped(BuildContext context) {
    if (!context.mounted) return;
    final guest = context.read<GuestService>();
    if (!guest.canRequestSuggestion) {
      showGuestSoftGate(context);
      return;
    }
    if (guest.isGuest) {
      guest.recordSuggestionUsed();
    }
    final health = context.read<HealthProvider>();
    if (health.hasTodaySuggestion) {
      regenerateSuggestionFlow(context);
    } else {
      health.getSuggestion();
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SuggestionScreen()),
    );
  }
}

@visibleForTesting
class TutorialCard extends StatelessWidget {
  const TutorialCard({
    required this.title,
    required this.message,
    required this.stepLabel,
    required this.isLast,
    required this.onNext,
    required this.onSkip,
    this.onBack,
  });

  final String title;
  final String message;
  final String stepLabel;
  final bool isLast;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.teal,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  stepLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (onBack != null)
                TextButton.icon(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_rounded, size: 16),
                  label: const Text("Back"),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                )
              else
                TextButton(
                  onPressed: onSkip,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: const Text("Skip"),
                ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onBack != null) ...[
                    TextButton(
                      onPressed: onSkip,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      ),
                      child: const Text("Skip"),
                    ),
                    const SizedBox(width: 4),
                  ],
                  FilledButton(
                    onPressed: onNext,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(isLast ? "Got it!" : "Got it \u2192"),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
