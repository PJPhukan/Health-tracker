class AppStrings {
  AppStrings._();

  static const String appName = 'Stock Plate';

  // Offline & Connectivity
  static const String offlineBannerText = "You're offline — showing cached data";
  static const String offlineSuggestionError =
      "You need an internet connection to get suggestions. Your logged data is saved and ready for when you're back online.";

  // Timeouts & Errors
  static const String networkTimeoutMessage =
      "That took longer than expected. Try again?";
  static const String suggestionGenericError =
      "Couldn't get suggestion, try again.";

  // Empty States
  static const String historyEmptyTitle = "Nothing logged yet";
  static const String historyEmptySubtitle =
      "Start by logging your first meal to build your activity history.";
  static const String historyEmptyAction = "Log a meal";

  static const String pantryEmptyTitle = "Your pantry is empty";
  static const String pantryEmptySubtitle =
      "Add items to your pantry so Stock Plate can suggest meals you can make right now.";
  static const String pantryEmptyAction = "Set up pantry";

  static const String progressEmptyMessage =
      "Keep logging daily — your progress charts will appear here after 3 days of data";

  // Milestones & Celebrations
  static const String streakMilestoneButton = "Keep it up →";
  static const String streakMilestoneDefaultSubtitle =
      "You're building a real habit. Keep going!";

  // Feedback
  static const String feedbackSuccessToast = "Glad it helped!";

  // Disclaimer & Legal
  static const String disclaimerTitle = "Before We Begin";
  static const String disclaimerMedicalNotice =
      "Stock Plate provides nutritional information and meal suggestions for general wellness purposes only. It is not medical advice, diagnosis, or treatment. Always consult a healthcare professional before making significant changes to your diet or fitness routine.";
  static const String disclaimerAcknowledgeButton = "I understand — let's go →";

  static const String privacyPolicyUrl = "https://stockplate.app/privacy";
  static const String termsOfServiceUrl = "https://stockplate.app/terms";
}
