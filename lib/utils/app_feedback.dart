import 'package:flutter/material.dart';

import 'app_error_formatter.dart';

class AppFeedback {
  const AppFeedback._();

  static void showSuccess(
    BuildContext context,
    String message, {
    SnackBarBehavior behavior = SnackBarBehavior.floating,
  }) {
    final theme = Theme.of(context);
    _show(
      context,
      SnackBar(
        content: Text(message),
        behavior: behavior,
        backgroundColor: theme.colorScheme.tertiaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }

  static void showInfo(
    BuildContext context,
    String message, {
    SnackBarBehavior behavior = SnackBarBehavior.floating,
  }) {
    final theme = Theme.of(context);
    _show(
      context,
      SnackBar(
        content: Text(message),
        behavior: behavior,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }

  static void showError(
    BuildContext context,
    Object error, {
    String? fallback,
    SnackBarBehavior behavior = SnackBarBehavior.floating,
  }) {
    final theme = Theme.of(context);
    _show(
      context,
      SnackBar(
        content: Text(AppErrorFormatter.format(error, fallback: fallback)),
        behavior: behavior,
        backgroundColor: theme.colorScheme.errorContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }

  static void _show(BuildContext context, SnackBar snackBar) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);
  }
}
