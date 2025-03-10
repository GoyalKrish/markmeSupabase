import 'package:flutter/material.dart';

class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String message;
  final String actionText;
  final VoidCallback onAction;
  final String? secondaryActionText;
  final VoidCallback? onSecondaryAction;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.message,
    required this.actionText,
    required this.onAction,
    this.secondaryActionText,
    this.onSecondaryAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              message,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onAction,
              child: Text(actionText),
            ),
            if (secondaryActionText != null && onSecondaryAction != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: TextButton(
                  onPressed: onSecondaryAction,
                  child: Text(secondaryActionText!),
                ),
              ),
          ],
        ),
      ),
    );
  }
} 