import 'package:mp_agency/core/data/app_data.dart';

/// 알림 종류 (데이터 테이블 기술서 notifications.type)
enum NotificationType {
  reserved('RESERVED', '🧾'),
  cancelled('CANCELLED', '↩️'),
  pickedUp('PICKED_UP', '🎉'),
  newReservation('NEW_RESERVATION', '🔔'),
  pickupReminder('PICKUP_REMINDER', '⏰'),
  noShow('NO_SHOW', '⌛'),
  recommendation('RECOMMENDATION', '✨');

  const NotificationType(this.code, this.emoji);
  final String code;
  final String emoji;

  static NotificationType fromCode(String? code) =>
      NotificationType.values.firstWhere(
        (t) => t.code == code,
        orElse: () => NotificationType.reserved,
      );

  /// 알림 설정에서 묶어서 켜고 끄는 단위
  NotificationGroup get group => switch (this) {
    recommendation => NotificationGroup.recommendation,
    newReservation => NotificationGroup.store,
    _ => NotificationGroup.reservation,
  };
}

/// 알림 설정 묶음 (MY-001 설정 관리)
enum NotificationGroup {
  reservation('예약·픽업 알림', '예약 완료, 픽업 마감 30분 전, 취소·환불 안내'),
  recommendation('추천 알림', '찜한 매장에 새 음식이 올라오면 알려드려요'),
  store('사장님 알림', '새 예약, 예약 취소, 노쇼 안내');

  const NotificationGroup(this.label, this.description);
  final String label;
  final String description;
}

/// 알림 (데이터 테이블 기술서 notifications 기준)
class AppNotification {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    required this.createdAt,
    this.referenceId,
    this.isRead = false,
    this.readAt,
  });

  final String id;
  final String userId;
  final NotificationType type;
  final String title;
  final String message;

  /// 관련 예약·상품 ID
  final String? referenceId;
  final bool isRead;
  final DateTime createdAt;

  /// 읽은 시각 (notifications.read_at)
  final DateTime? readAt;

  AppNotification read() => AppNotification(
    id: id,
    userId: userId,
    type: type,
    title: title,
    message: message,
    createdAt: createdAt,
    referenceId: referenceId,
    isRead: true,
    readAt: DateTime.now(),
  );

  // ───────── Firestore 변환 (notifications 컬렉션) ─────────

  factory AppNotification.fromMap(String id, Map<String, dynamic> d) =>
      AppNotification(
        id: id,
        userId: d['userId'] as String? ?? '',
        type: NotificationType.fromCode(d['type'] as String?),
        title: d['title'] as String? ?? '',
        message: d['message'] as String? ?? '',
        referenceId: d['referenceId'] as String?,
        isRead: d['isRead'] as bool? ?? false,
        createdAt: AppData.date(d['createdAt']) ?? DateTime.now(),
        readAt: AppData.date(d['readAt']),
      );

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'type': type.code,
    'title': title,
    'message': message,
    'referenceId': referenceId,
    'isRead': isRead,
    'createdAt': AppData.ts(createdAt),
    'readAt': AppData.ts(readAt),
  };
}
