import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../theme/markme_theme.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

class NotificationOverlay extends StatelessWidget {
  final Widget child;

  const NotificationOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          child,
          _NotificationToast(),
        ],
      ),
    );
  }
}

class _NotificationToast extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationService>(
      builder: (context, notificationService, _) {
        if (!notificationService.isVisible) {
          return const SizedBox.shrink();
        }

        // Determine colors based on notification type
        final Color backgroundColor;
        final Color iconColor;
        final IconData iconData;

        switch (notificationService.type) {
          case NotificationType.success:
            backgroundColor = Colors.green.shade700;
            iconColor = MarkMeTheme.primaryWhite;
            iconData = Icons.check_circle_outline;
            break;
          case NotificationType.error:
            backgroundColor = Colors.red.shade700;
            iconColor = MarkMeTheme.primaryWhite;
            iconData = Icons.error_outline;
            break;
          case NotificationType.warning:
            backgroundColor = Colors.orange.shade700;
            iconColor = MarkMeTheme.darkBackground;
            iconData = Icons.warning_amber_outlined;
            break;
          case NotificationType.info:
          default:
            backgroundColor = MarkMeTheme.primaryYellow;
            iconColor = MarkMeTheme.darkBackground;
            iconData = Icons.info_outline;
            break;
        }

        return SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              child: AnimatedOpacity(
                opacity: notificationService.isVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Material(
                  elevation: 6,
                  borderRadius: BorderRadius.circular(12),
                  color: backgroundColor,
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.9,
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 12.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          iconData,
                          color: iconColor,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            notificationService.message ?? '',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: iconColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
