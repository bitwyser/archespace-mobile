import 'package:flutter/material.dart';

/// Consistent, tinted snackbars used app-wide (Law of Similarity): success
/// follows the accent color (the seeded theme's primary), errors use the error
/// color, and neutral notices use a quiet surface tint. Each carries a leading
/// icon so the kind reads at a glance (Doherty: clear, immediate feedback).
///
/// Mirrors the web app's accent-colored success toast. Prefer these over
/// calling `ScaffoldMessenger.showSnackBar` directly so every message looks and
/// behaves the same.
enum SnackKind { success, error, info }

/// Show a success snackbar (accent-tinted). [message] should be short.
void showSuccessSnack(BuildContext context, String message) =>
    showAppSnack(context, message, SnackKind.success);

/// Show an error snackbar (error-tinted).
void showErrorSnack(BuildContext context, String message) =>
    showAppSnack(context, message, SnackKind.error);

/// Show a neutral/informational snackbar.
void showInfoSnack(BuildContext context, String message) =>
    showAppSnack(context, message, SnackKind.info);

void showAppSnack(BuildContext context, String message, SnackKind kind) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  showAppSnackVia(messenger, Theme.of(context).colorScheme, message, kind);
}

/// Success variant for a captured messenger (see [showAppSnackVia]).
void showSuccessVia(
  ScaffoldMessengerState messenger,
  ColorScheme scheme,
  String message,
) => showAppSnackVia(messenger, scheme, message, SnackKind.success);

/// Error variant for a captured messenger (see [showAppSnackVia]).
void showErrorVia(
  ScaffoldMessengerState messenger,
  ColorScheme scheme,
  String message,
) => showAppSnackVia(messenger, scheme, message, SnackKind.error);

/// Info variant for a captured messenger (see [showAppSnackVia]).
void showInfoVia(
  ScaffoldMessengerState messenger,
  ColorScheme scheme,
  String message,
) => showAppSnackVia(messenger, scheme, message, SnackKind.info);

/// Lower-level variant for code that captures the [ScaffoldMessengerState] and
/// [ColorScheme] before an async gap (so no `BuildContext` is used after an
/// await). Prefer [showSuccessSnack] / [showErrorSnack] with a live context
/// where possible.
void showAppSnackVia(
  ScaffoldMessengerState messenger,
  ColorScheme scheme,
  String message,
  SnackKind kind,
) {
  final (Color background, Color foreground, IconData icon) = switch (kind) {
    SnackKind.success => (
      scheme.primaryContainer,
      scheme.onPrimaryContainer,
      Icons.check_circle_outline,
    ),
    SnackKind.error => (
      scheme.errorContainer,
      scheme.onErrorContainer,
      Icons.error_outline,
    ),
    SnackKind.info => (
      scheme.secondaryContainer,
      scheme.onSecondaryContainer,
      Icons.info_outline,
    ),
  };

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: background,
        showCloseIcon: true,
        closeIconColor: foreground,
        content: Row(
          children: [
            Icon(icon, size: 20, color: foreground),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: TextStyle(color: foreground)),
            ),
          ],
        ),
      ),
    );
}
