import 'package:flutter/material.dart';

import 'gm_menu_registry.dart';

/// Shows a [MaterialBanner] when [controller] has an active GM notification.
class GmNotificationOverlay extends StatelessWidget {
  const GmNotificationOverlay({
    super.key,
    required this.controller,
    required this.onTap,
    required this.child,
  });

  final GmNotificationController controller;
  final ValueChanged<GmNotificationState> onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final notification = controller.current;
        return Column(
          children: [
            if (notification != null)
              MaterialBanner(
                key: Key('gm-notification-${notification.callId}'),
                content: Text(notification.text),
                leading: const Icon(Icons.notifications_outlined),
                actions: [
                  TextButton(
                    onPressed: () {
                      onTap(notification);
                      controller.dismiss();
                    },
                    child: Text(notification.title),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: controller.dismiss,
                  ),
                ],
              ),
            Expanded(child: child),
          ],
        );
      },
    );
  }
}
