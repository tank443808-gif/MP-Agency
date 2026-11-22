import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'package:mp_agency/core/data/app_data.dart';
import 'package:mp_agency/features/auth/models/app_user.dart';
import 'package:mp_agency/features/favorite/services/favorite_service.dart';
import 'package:mp_agency/features/notification/services/notification_service.dart';
import 'package:mp_agency/features/product/services/product_service.dart';
import 'package:mp_agency/features/recommendation/services/behavior_service.dart';
import 'package:mp_agency/features/reservation/services/reservation_service.dart';
import 'package:mp_agency/features/store/services/store_service.dart';

/// 로그인하면 Firestore 실시간 구독을 시작하고, 로그아웃하면 멈춤.
/// 메모리 모드(미리보기·테스트)에서는 아무것도 하지 않음.
class DataSync {
  DataSync._();
  static final instance = DataSync._();

  String? _uid;
  Future<void>? _ready;

  /// 구독 시작. 매장·상품·내 예약 등 첫 데이터를 다 받으면 완료.
  Future<void> start(AppUser user) {
    if (!AppData.useFirestore) return Future.value();
    if (_uid == user.uid && _ready != null) return _ready!;
    stop();
    _uid = user.uid;
    return _ready = _start(user);
  }

  Future<void> _start(AppUser user) async {
    await Future.wait([
      StoreService.instance.bindRemote(),
      ProductService.instance.bindRemote(),
    ]);
    await _ensureDemoData();
    await Future.wait([
      ReservationService.instance.bindRemote(user.uid),
      NotificationService.instance.bindRemote(user.uid),
      FavoriteService.instance.bindRemote(user.uid),
      BehaviorService.instance.bindRemote(user.uid),
    ]);
    ReservationService.instance.checkDeadlines();
  }

  /// 로그아웃: 구독을 멈추고 들고 있던 사본을 비움
  void stop() {
    if (!AppData.useFirestore) return;
    StoreService.instance.unbind();
    ProductService.instance.unbind();
    ReservationService.instance.unbind();
    NotificationService.instance.unbind();
    FavoriteService.instance.unbind();
    BehaviorService.instance.unbind();
    _uid = null;
    _ready = null;
  }

  /// 시연용 예시 데이터
  /// - 예시 매장 4곳이 없으면 만들기
  /// - 주인이 없는 예시 매장에 판매 중인 상품이 하나도 없으면 새로 채우기
  ///   (예시 상품은 마감 시간이 지금부터 몇 시간 뒤라, 시간이 지나면 다시 채움)
  Future<void> _ensureDemoData() async {
    try {
      final db = AppData.db;
      final stores = StoreService.instance;
      // 1) 매장 먼저 (보안 규칙이 상품을 만들 때 매장 주인을 확인하므로)
      final storeBatch = db.batch();
      var storeWrites = 0;
      for (final s in StoreService.sampleStores) {
        if (stores.findById(s.id) != null) continue;
        storeBatch.set(db.collection('stores').doc(s.id), {
          ...s.toMap(),
          'isSample': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        storeWrites++;
      }
      if (storeWrites > 0) await storeBatch.commit();

      // 2) 판매 중인 예시 상품이 없으면 채우기
      final batch = db.batch();
      var writes = 0;
      final unowned = {
        for (final s in StoreService.sampleStores)
          if ((stores.findById(s.id)?.ownerId) == null) s.id,
      };
      final hasLive = ProductService.instance.onSale().any(
        (p) => unowned.contains(p.storeId),
      );
      if (!hasLive && unowned.isNotEmpty) {
        final now = DateTime.now();
        final items = ProductService.instance
            .sampleProducts(
              now,
              idPrefix: 'sample${now.millisecondsSinceEpoch}-',
            )
            .where((p) => unowned.contains(p.storeId));
        for (final p in items) {
          batch.set(db.collection('products').doc(p.id), {
            ...p.toMap(),
            'isSample': true,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          writes++;
        }
      }

      if (writes > 0) await batch.commit();
    } catch (e) {
      debugPrint('예시 데이터 채우기 실패: $e');
    }
  }
}
