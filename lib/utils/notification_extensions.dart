import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import 'package:provider/provider.dart';

/// Extension on BuildContext to provide easy access to the notification service
extension NotificationExtension on BuildContext {
  /// Shows a notification with the given message and type
  void showNotification({
    required String message,
    NotificationType type = NotificationType.info,
  }) {
    Provider.of<NotificationService>(this, listen: false).show(
      message: message,
      type: type,
    );
  }

  /// Shows a success notification
  void showSuccessNotification(String message) {
    showNotification(
      message: message,
      type: NotificationType.success,
    );
  }

  /// Shows an error notification
  void showErrorNotification(String message) {
    showNotification(
      message: message,
      type: NotificationType.error,
    );
  }

  /// Shows an info notification
  void showInfoNotification(String message) {
    showNotification(
      message: message,
      type: NotificationType.info,
    );
  }

  /// Shows a warning notification
  void showWarningNotification(String message) {
    showNotification(
      message: message,
      type: NotificationType.warning,
    );
  }
}
