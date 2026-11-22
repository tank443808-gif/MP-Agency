import 'package:flutter/material.dart';

import 'package:mp_agency/core/theme/app_theme.dart';
import 'package:mp_agency/features/notification/screens/notification_screen.dart';
import 'package:mp_agency/features/notification/services/notification_service.dart';

/// 알림 종 버튼 + 안 읽은 알림 수 빨간 점
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: NotificationService.instance.watchUnread(userId),
      builder: (context, snap) {
        final count = snap.data ?? 0;
        return IconButton(
          tooltip: '알림',
          style: IconButton.styleFrom(backgroundColor: Colors.white),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => NotificationScreen(userId: userId),
            ),
          ),
          icon: Badge(
            isLabelVisible: count > 0,
            label: Text('$count'),
            backgroundColor: AppColors.urgent,
            child: const Icon(
              Icons.notifications_none_rounded,
              color: AppColors.text,
            ),
          ),
        );
      },
    );
  }
}
