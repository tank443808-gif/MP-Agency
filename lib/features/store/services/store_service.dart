import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'package:mp_agency/core/data/app_data.dart';
import 'package:mp_agency/features/auth/models/app_user.dart';
import 'package:mp_agency/features/location/services/location_service.dart';
import 'package:mp_agency/features/product/models/product.dart';
import 'package:mp_agency/features/store/models/store.dart';

/// 매장 데이터 처리 (stores 컬렉션)
///
/// Firestore 모드: [bindRemote]로 실시간 구독해 사본을 유지.
/// 메모리 모드(미리보기·테스트): 예시 매장으로 시작.
class StoreService {
  StoreService._();
  static final instance = StoreService._();

  final _changes = StreamController<void>.broadcast();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  CollectionReference<Map<String, dynamic>> get _col =>
      AppData.db.collection('stores');

  late final List<Store> _stores = AppData.useFirestore
      ? <Store>[]
      : List.of(sampleStores);

  /// Firestore 실시간 구독 시작. 첫 데이터가 오면 완료.
  Future<void> bindRemote() {
    final ready = Completer<void>();
    _sub?.cancel();
    _sub = _col.snapshots().listen(
      (snap) {
        _stores
          ..clear()
          ..addAll(snap.docs.map((d) => Store.fromMap(d.id, d.data())));
        _changes.add(null);
        if (!ready.isCompleted) ready.complete();
      },
      onError: (Object e) {
        debugPrint('stores 구독 실패: $e');
        if (!ready.isCompleted) ready.complete();
      },
    );
    return ready.future;
  }

  void unbind() {
    _sub?.cancel();
    _sub = null;
  }

  /// 예시 매장 (메모리 모드 시작 데이터, Firestore가 비었을 때 채우는 데이터)
  static const List<Store> sampleStores = [
    Store(
      id: 's1',
      name: '신구 베이커리',
      category: ProductCategory.bakery,
      emoji: '🥐',
      address: '경기 성남시 중원구 광명로 377 신구대학교 정문 앞',
      latitude: 37.4499,
      longitude: 127.1695,
      description: '매일 아침 직접 굽는 동네 빵집이에요.',
      pickupGuide: '매장 안 카운터에서 예약 번호를 말해 주세요.',
      contactPhone: '031-000-0001',
      openTime: '08:00',
      closeTime: '21:00',
    ),
    Store(
      id: 's2',
      name: '편의점 신구대점',
      category: ProductCategory.convenience,
      emoji: '🏪',
      address: '경기 성남시 중원구 광명로 365 1층',
      latitude: 37.4466,
      longitude: 127.1701,
      description: '24시간 편의점. 유통기한 임박 간편식을 할인해요.',
      pickupGuide: '계산대에서 앱의 예약 화면을 보여 주세요.',
      contactPhone: '031-000-0002',
      openTime: '00:00',
      closeTime: '24:00',
    ),
    Store(
      id: 's3',
      name: '카페 다온',
      category: ProductCategory.cafe,
      emoji: '☕',
      address: '경기 성남시 중원구 금광동 2층',
      latitude: 37.4518,
      longitude: 127.1660,
      description: '오늘 만든 디저트와 커피 세트를 마감 할인해요.',
      pickupGuide: '픽업 선반에 이름표를 붙여 둘게요.',
      contactPhone: '031-000-0003',
      openTime: '10:00',
      closeTime: '22:00',
    ),
    Store(
      id: 's4',
      name: '한끼 도시락',
      category: ProductCategory.meal,
      emoji: '🍱',
      address: '경기 성남시 중원구 금광로 120',
      latitude: 37.4441,
      longitude: 127.1638,
      description: '집밥 같은 도시락 전문점이에요.',
      pickupGuide: '포장해서 계산대 옆에 준비해 둘게요.',
      contactPhone: '031-000-0004',
      openTime: '10:30',
      closeTime: '20:30',
    ),
  ];

  List<Store> get all => List.unmodifiable(_stores);

  Stream<List<Store>> watchAll() async* {
    yield all;
    await for (final _ in _changes.stream) {
      yield all;
    }
  }

  Store? findById(String id) {
    for (final s in _stores) {
      if (s.id == id) return s;
    }
    return null;
  }

  Stream<Store?> watchById(String id) async* {
    yield findById(id);
    await for (final _ in _changes.stream) {
      yield findById(id);
    }
  }

  /// 판매자의 매장. 없으면 같은 이름의 예시 매장을 맡거나 새로 만듦.
  Store storeOf(AppUser seller) {
    for (final s in _stores) {
      if (s.ownerId == seller.uid) return s;
    }
    final name = (seller.storeName?.trim().isNotEmpty ?? false)
        ? seller.storeName!.trim()
        : '${seller.nickname}의 가게';

    final i = _stores.indexWhere((s) => s.ownerId == null && s.name == name);
    if (i >= 0) {
      _stores[i] = _stores[i].copyWith(ownerId: seller.uid);
      final claimed = _stores[i];
      AppData.write(
        '매장 맡기',
        () => _col.doc(claimed.id).update({
          'ownerId': seller.uid,
          'updatedAt': FieldValue.serverTimestamp(),
        }),
      );
      return claimed;
    }

    final store = Store(
      id: 'store-${seller.uid}',
      ownerId: seller.uid,
      name: name,
      category: ProductCategory.meal,
      address: '주소를 입력해 주세요',
      latitude: LocationService.fallbackLatitude,
      longitude: LocationService.fallbackLongitude,
      pickupGuide: '매장에서 픽업 번호를 말해 주세요.',
    );
    _stores.add(store);
    _changes.add(null);
    AppData.write(
      '매장 만들기',
      () => _col.doc(store.id).set({
        ...store.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    );
    return store;
  }

  void update(Store store) {
    final i = _stores.indexWhere((s) => s.id == store.id);
    if (i < 0) return;
    _stores[i] = store;
    _changes.add(null);
    AppData.write(
      '매장 수정',
      () => _col.doc(store.id).set({
        ...store.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)),
    );
  }
}
