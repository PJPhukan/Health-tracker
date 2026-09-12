import 'package:flutter/material.dart';

/// Lets a background operation (like the fire-and-forget pantry auto-deduct)
/// show a SnackBar regardless of which screen is currently on top — the
/// `MaterialApp` is wired to [scaffoldMessengerKey] in main.dart.
class ToastCenter {
  ToastCenter._();

  static final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  static final navigatorKey = GlobalKey<NavigatorState>();

  static void show(String message, {SnackBarAction? action}) {
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(message), action: action),
    );
  }

  /// A message with a "View" action that pushes [builder] on the root
  /// navigator — used by the pantry auto-deduct toast.
  static void showWithView(String message, WidgetBuilder builder) {
    show(
      message,
      action: SnackBarAction(
        label: 'View',
        onPressed: () =>
            navigatorKey.currentState?.push(MaterialPageRoute(builder: builder)),
      ),
    );
  }
}
