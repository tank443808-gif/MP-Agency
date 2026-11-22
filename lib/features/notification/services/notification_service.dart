import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'package:mp_agency/core/data/app_data.dart';
import 'package:mp_agency/features/notification/models/app_notification.dart';

/// 알림 처리 (기능명세 NOTI-001, notifications 컬렉션)
///
/// Firestore 모드: 내 알림만 실시간 구독 ([bindRemote]).
/// 다른 사람(사장님·손님)에게 보내는 알림은 문서만 만듦.
/// 알림 설정(끈 묶음)은 users/{uid}.mutedNotificationGroups에 저장하고,
/// 받는 쪽에서 꺼 둔 묶음은 목록에서 숨김.
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _items = <AppNotification>[];

  /// 사용자별로 끈 알림 묶음
  final _muted = <String, Set<NotificationGroup>>{};
  final _changes = StreamController<void>.broadcast();
  int _seq = 0;
  final _subs = <StreamSubscription<Object?>>[];

  CollectionReference<Map<String, dynamic>> get _col =>
      AppData.db.collection('notifications');

  Future<void> bindRemote(String userId) {
    final ready = Completer<void>();
    unbind();
    _subs.add(
      _col
          .where('userId', isEqualTo: userId)
          .snapshots()
          .listen(
            (snap) {
              _items
                ..clear()
                ..addAll(
                  snap.docs.map((d) => AppNotification.fromMap(d.id, d.data())),
                );
              _changes.add(null);
              if (!ready.isCompleted) ready.complete();
            },
            onError: (Object e) {
              debugPrint('notifications 구독 실패: $e');
              if (!ready.isCompleted) ready.complete();
            },
          ),
    );
    // 알림 설정
    _subs.add(
      AppData.db.collection('users').doc(userId).snapshots().listen((doc) {
        final codes = (doc.data()?['mutedNotificationGroups'] as List?) ?? [];
        _muted[userId] = {
          for (final g in NotificationGroup.values)
            if (codes.contains(g.name)) g,
        };
        _changes.add(null);
      }, onError: (Object e) => debugPrint('알림 설정 구독 실패: $e')),
    );
    return ready.future;
  }

  void unbind() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _items.clear();
    _muted.clear();
  }

  /// 내 알림 (최신순). 꺼 둔 묶음은 빠짐.
  List<AppNotification> of(String userId) =>
      _items
          .where((n) => n.userId == userId && isOn(userId, n.type.group))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  Stream<List<AppNotification>> watch(String userId) async* {
    yield of(userId);
    await for (final _ in _changes.stream) {
      yield of(userId);
    }
  }

  /// 안 읽은 알림 수
  Stream<int> watchUnread(String userId) =>
      watch(userId).map((list) => list.where((n) => !n.isRead).length);

  bool isOn(String userId, NotificationGroup group) =>
      !(_muted[userId]?.contains(group) ?? false);

  void setOn(String userId, NotificationGroup group, bool on) {
    final set = _muted.putIfAbsent(userId, () => <NotificationGroup>{});
    on ? set.remove(group) : set.add(group);
    _changes.add(null);
    final codes = [for (final g in set) g.name];
    AppData.write(
      '알림 설정',
      () => AppData.db.collection('users').doc(userId).update({
        'mutedNotificationGroups': codes,
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    );
  }

  /// 알림 보내기.
  /// 메모리 모드에서는 받는 사람이 그 묶음을 꺼 두었으면 보내지 않음.
  void send({
    required String userId,
    required NotificationType type,
    required String title,
    required String message,
    String? referenceId,
  }) {
    final n = AppNotification(
      id: AppData.useFirestore ? _col.doc().id : 'n${_seq++}',
      userId: userId,
      type: type,
      title: title,
      message: message,
      referenceId: referenceId,
      createdAt: DateTime.now(),
    );
    if (AppData.useFirestore) {
      // 내 알림이면 구독으로 바로 들어옴
      AppData.write('알림 보내기', () => _col.doc(n.id).set(n.toMap()));
      return;
    }
    if (!isOn(userId, type.group)) return;
    _items.add(n);
    _changes.add(null);
  }

  void markAllRead(String userId) {
    final unread = <String>[];
    for (var i = 0; i < _items.length; i++) {
      if (_items[i].userId == userId && !_items[i].isRead) {
        _items[i] = _items[i].read();
        unread.add(_items[i].id);
      }
    }
    _changes.add(null);
    if (unread.isEmpty) return;
    AppData.write('알림 읽음', () async {
      final batch = AppData.db.batch();
      for (final id in unread) {
        batch.update(_col.doc(id), {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    });
  }
}
