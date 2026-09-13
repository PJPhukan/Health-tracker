import 'package:flutter/material.dart';

import '../screens/auth/signup_screen.dart';
import '../theme/app_theme.dart';

/// Soft gate shown when a guest user tries to exceed the 3-suggestion limit.
void showGuestSoftGate(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      icon: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.tealLight.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.auto_awesome_rounded,
          color: AppColors.teal,
          size: 28,
        ),
      ),
      title: const Text(
        'Free suggestions limit',
        textAlign: TextAlign.center,
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      content: const Text(
        "You've used 3 free suggestions — create a free account to keep going",
        textAlign: TextAlign.center,
        style: TextStyle(height: 1.4),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SignupScreen(isMotivated: true),
                ),
              );
            },
            child: const Text('Sign up free →'),
          ),
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Maybe later'),
        ),
      ],
    ),
  );
}
