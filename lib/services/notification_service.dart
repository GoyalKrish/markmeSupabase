import 'dart:async';
import 'package:flutter/material.dart';

enum NotificationType {
  success,
  error,
  info,
  warning,
}

class NotificationService extends ChangeNotifier {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  // Current notification data
  String? _message;
  NotificationType? _type;
  bool _isVisible = false;
  Timer? _dismissTimer;

  // Getters for the notification state
  String? get message => _message;
  NotificationType? get type => _type;
  bool get isVisible => _isVisible;

  // Show a notification with the given message and type
  void show({
    required String message,
    NotificationType type = NotificationType.info,
  }) {
    // Cancel any existing timer to handle preemption
    _dismissTimer?.cancel();

    // Update notification data
    _message = message;
    _type = type;
    _isVisible = true;
    notifyListeners();

    // Set timer to auto-dismiss after 1 second
    _dismissTimer = Timer(const Duration(seconds: 1), () {
      _isVisible = false;
      notifyListeners();
    });
  }

  // Manually dismiss the current notification
  void dismiss() {
    _dismissTimer?.cancel();
    _isVisible = false;
    notifyListeners();
  }
}
