import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design system for Health Tracker — a calm, premium feel:
/// deep-teal base, warm cream background, one soft-coral accent.
class AppColors {
  static const teal = Color(0xFF0F4C4C); // primary / headings
  static const tealDeep = Color(0xFF0A3838);
  static const tealLight = Color(0xFF1A6B5A);
  static const cream = Color(0xFFF7F4EE); // app background
  static const surface = Color(0xFFFFFFFF); // cards
  static const surfaceMuted = Color(0xFFF0ECE3); // inset / soft fills
  static const accent = Color(0xFFE5705B); // CTAs (soft coral)
  static const accentSoft = Color(0xFFFBE9E4);
  static const onTrack = Color(0xFF3E9C7A); // muted green
  static const onTrackSoft = Color(0xFFE4F1EA);
  static const behind = Color(0xFFC98A2E); // muted amber (never harsh red)
  static const behindSoft = Color(0xFFF7EEDD);
  static const textPrimary = Color(0xFF1F2A2A);
  static const textSecondary = Color(0xFF6B7671);
  static const divider = Color(0xFFE7E2D8);
  static const sleep = Color(0xFF6C63FF);
  static const water = Color(0xFF4DB6E5);
}

class AppSpacing {
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double radius = 16;
  static const double radiusSm = 12;
}

/// Soft, low-contrast elevation used instead of borders.
const List<BoxShadow> kSoftShadow = [
  BoxShadow(
    color: Color(0x14000000),
    blurRadius: 24,
    offset: Offset(0, 8),
    spreadRadius: -6,
  ),
];

/// Standard gradients used across the app.
class AppGradients {
  /// Primary gradient for page headers.
  static const headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0F4C4C),
      Color(0xFF1A6B5A),
      Color(0xFF0F4C4C),
    ],
  );

  /// Subtle accent gradient for special cards.
  static const accentGlow = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFBE9E4),
      Color(0xFFF0ECE3),
    ],
  );
}

/// Standard animation constants.
class AppAnimations {
  static const entranceDuration = Duration(milliseconds: 700);
  static const shortDuration = Duration(milliseconds: 300);
  static const microDuration = Duration(milliseconds: 160);
  static const shimmerDuration = Duration(milliseconds: 1800);
  static const entranceCurve = Curves.easeOutCubic;
}

class AppTheme {
  static ThemeData get light {
    final base = ColorScheme.fromSeed(
      seedColor: AppColors.teal,
      primary: AppColors.teal,
      secondary: AppColors.accent,
      surface: AppColors.surface,
      brightness: Brightness.light,
    );

    final textTheme = GoogleFonts.interTextTheme().apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    ).copyWith(
      displaySmall: GoogleFonts.inter(
          fontSize: 30, fontWeight: FontWeight.w600, letterSpacing: -0.5),
      headlineSmall: GoogleFonts.inter(
          fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: -0.2),
      titleLarge: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600),
      titleMedium: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
      bodyLarge: GoogleFonts.inter(
          fontSize: 16, height: 1.55, fontWeight: FontWeight.w400),
      bodyMedium: GoogleFonts.inter(
          fontSize: 14, height: 1.5, fontWeight: FontWeight.w400),
      labelLarge: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
      labelSmall: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.4,
          color: AppColors.textSecondary),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: base,
      scaffoldBackgroundColor: AppColors.cream,
      textTheme: textTheme,
      dividerTheme: const DividerThemeData(
          color: AppColors.divider, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.cream,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        foregroundColor: AppColors.textPrimary,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radius)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.md),
        border: _inputBorder(AppColors.divider),
        enabledBorder: _inputBorder(AppColors.divider),
        focusedBorder: _inputBorder(AppColors.teal, width: 1.6),
        hintStyle: const TextStyle(color: AppColors.textSecondary),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.35),
          disabledForegroundColor: Colors.white,
          minimumSize: const Size.fromHeight(56),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radius)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.teal,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: AppColors.divider),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radius)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        elevation: 0,
        height: 68,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.accentSoft,
        labelTextStyle: WidgetStateProperty.all(textTheme.labelSmall),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.tealDeep,
        contentTextStyle: GoogleFonts.inter(
            color: Colors.white, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        borderSide: BorderSide(color: color, width: width),
      );
}

/// Status against a goal — drives the calm colour coding.
enum GoalStatus { onTrack, behind, neutral }

extension GoalStatusColors on GoalStatus {
  Color get fg => switch (this) {
        GoalStatus.onTrack => AppColors.onTrack,
        GoalStatus.behind => AppColors.behind,
        GoalStatus.neutral => AppColors.textSecondary,
      };

  Color get bg => switch (this) {
        GoalStatus.onTrack => AppColors.onTrackSoft,
        GoalStatus.behind => AppColors.behindSoft,
        GoalStatus.neutral => AppColors.surfaceMuted,
      };
}
