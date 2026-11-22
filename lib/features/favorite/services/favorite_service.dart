import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'package:mp_agency/core/data/app_data.dart';

/// 찜한 매장 (favorites 컬렉션, 문서 ID = "회원ID_매장ID")
///
/// Firestore 모드: 내 찜만 실시간 구독 ([bindRemote]). 메모리 모드: 앱 안에서만.
class FavoriteService {
  FavoriteService._();
  static final instance = FavoriteService._();

  final _byUser = <String, Set<String>>{};
  final _changes = StreamController<void>.broadcast();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  CollectionReference<Map<String, dynamic>> get _col =>
      AppData.db.collection('favorites');

  Future<void> bindRemote(String userId) {
    final ready = Completer<void>();
    _sub?.cancel();
    _sub = _col
        .where('userId', isEqualTo: userId)
        .snapshots()
        .listen(
          (snap) {
            _byUser[userId] = {
              for (final d in snap.docs) d.data()['storeId'] as String,
            };
            _changes.add(null);
            if (!ready.isCompleted) ready.complete();
          },
          onError: (Object e) {
            debugPrint('favorites 구독 실패: $e');
            if (!ready.isCompleted) ready.complete();
          },
        );
    return ready.future;
  }

  void unbind() {
    _sub?.cancel();
    _sub = null;
    _byUser.clear();
  }

  Set<String> storeIds(String userId) =>
      Set.unmodifiable(_byUser[userId] ?? const <String>{});

  Stream<Set<String>> watch(String userId) async* {
    yield storeIds(userId);
    await for (final _ in _changes.stream) {
      yield storeIds(userId);
    }
  }

  /// 이 매장을 찜한 사용자들 (추천 알림용)
  Future<List<String>> fansOf(String storeId) async {
    if (!AppData.useFirestore) {
      return [
        for (final e in _byUser.entries)
          if (e.value.contains(storeId)) e.key,
      ];
    }
    try {
      final snap = await _col.where('storeId', isEqualTo: storeId).get();
      return [for (final d in snap.docs) d.data()['userId'] as String];
    } catch (e) {
      debugPrint('찜한 사용자 조회 실패: $e');
      return const [];
    }
  }

  bool isFavorite(String userId, String storeId) =>
      _byUser[userId]?.contains(storeId) ?? false;

  /// 찜 켜기/끄기. 바뀐 뒤 상태(찜이면 true)를 돌려줌.
  bool toggle(String userId, String storeId) {
    final set = _byUser.putIfAbsent(userId, () => <String>{});
    final now = !set.remove(storeId);
    if (now) set.add(storeId);
    _changes.add(null);
    AppData.write('찜', () {
      final doc = _col.doc('${userId}_$storeId');
      return now
          ? doc.set({
              'userId': userId,
              'storeId': storeId,
              'createdAt': FieldValue.serverTimestamp(),
            })
          : doc.delete();
    });
    return now;
  }
}
