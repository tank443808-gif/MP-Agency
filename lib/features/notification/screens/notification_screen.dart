import 'package:flutter/material.dart';

import 'package:mp_agency/core/theme/app_theme.dart';
import 'package:mp_agency/core/utils/formatters.dart';
import 'package:mp_agency/features/notification/models/app_notification.dart';
import 'package:mp_agency/features/notification/services/notification_service.dart';

/// 알림 목록. 화면을 열면 모두 읽음 처리.
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key, required this.userId});

  final String userId;

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  /// 들어올 때 안 읽었던 알림 (화면에 점 표시용)
  late final Set<String> _unread = NotificationService.instance
      .of(widget.userId)
      .where((n) => !n.isRead)
      .map((n) => n.id)
      .toSet();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => NotificationService.instance.markAllRead(widget.userId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('알림')),
      body: StreamBuilder<List<AppNotification>>(
        stream: NotificationService.instance.watch(widget.userId),
        builder: (context, snap) {
          final items = snap.data ?? const <AppNotification>[];
          if (items.isEmpty) {
            return const Center(
              child: Text(
                '아직 알림이 없어요.\n예약하면 여기로 소식을 보내드릴게요.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.subText, height: 1.5),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final n = items[i];
              final isNew = _unread.contains(n.id);
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isNew ? Colors.white : AppColors.cream,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isNew
                        ? AppColors.orange.withValues(alpha: 0.4)
                        : AppColors.border,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(n.type.emoji, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(n.title, style: AppFonts.display(size: 15)),
                          const SizedBox(height: 2),
                          Text(
                            n.message,
                            style: const TextStyle(fontSize: 13, height: 1.4),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formatClock(n.createdAt),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.subText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isNew)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(top: 6),
                        decoration: const BoxDecoration(
                          color: AppColors.urgent,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
