import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'package:mp_agency/core/data/app_data.dart';
import 'package:mp_agency/features/product/models/product.dart';

/// 행동 유형 (데이터 테이블 기술서 user_behavior_events.event_type)
enum BehaviorType {
  viewProduct('VIEW_PRODUCT', 1),
  search('SEARCH', 1),
  filterCategory('FILTER_CATEGORY', 1),
  clickRecommendation('CLICK_RECOMMENDATION', 2),
  reserve('RESERVE', 3),
  pickup('PICKUP', 4);

  const BehaviorType(this.code, this.weight);
  final String code;

  static BehaviorType fromCode(String? code) => BehaviorType.values.firstWhere(
    (t) => t.code == code,
    orElse: () => BehaviorType.viewProduct,
  );

  /// 취향 분석에서 이 행동을 얼마나 중요하게 볼지
  final int weight;
}

/// 사용자 행동 기록 1건
class BehaviorEvent {
  const BehaviorEvent({
    required this.userId,
    required this.type,
    required this.occurredAt,
    this.productId,
    this.category,
    this.price,
    this.searchQuery,
  });

  final String userId;
  final BehaviorType type;
  final String? productId;
  final ProductCategory? category;

  /// 그때 본·예약한 상품의 할인가 (가격대 분석용)
  final int? price;
  final String? searchQuery;
  final DateTime occurredAt;

  factory BehaviorEvent.fromMap(Map<String, dynamic> d) => BehaviorEvent(
    userId: d['userId'] as String? ?? '',
    type: BehaviorType.fromCode(d['eventType'] as String?),
    productId: d['productId'] as String?,
    category: d['categoryCode'] == null
        ? null
        : ProductCategory.fromCode(d['categoryCode'] as String?),
    price: d['price'] == null ? null : AppData.toInt(d['price']),
    searchQuery: d['searchQuery'] as String?,
    occurredAt: AppData.date(d['occurredAt']) ?? DateTime.now(),
  );

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'eventType': type.code,
    'productId': productId,
    'categoryCode': category?.code,
    'price': price,
    'searchQuery': searchQuery,
    'occurredAt': AppData.ts(occurredAt),
  };
}

/// 사용자 행동 기록 (기능명세 AI-001 취향 분석의 기초 데이터, user_behavior_events 컬렉션)
///
/// Firestore 모드: 내 기록만 구독해 추천 계산에 씀 ([bindRemote]).
class BehaviorService {
  BehaviorService._();
  static final instance = BehaviorService._();

  final _events = <BehaviorEvent>[];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  CollectionReference<Map<String, dynamic>> get _col =>
      AppData.db.collection('user_behavior_events');

  Future<void> bindRemote(String userId) {
    final ready = Completer<void>();
    _sub?.cancel();
    _sub = _col
        .where('userId', isEqualTo: userId)
        .snapshots()
        .listen(
          (snap) {
            _events
              ..clear()
              ..addAll(snap.docs.map((d) => BehaviorEvent.fromMap(d.data())));
            if (!ready.isCompleted) ready.complete();
          },
          onError: (Object e) {
            debugPrint('행동 기록 구독 실패: $e');
            if (!ready.isCompleted) ready.complete();
          },
        );
    return ready.future;
  }

  void unbind() {
    _sub?.cancel();
    _sub = null;
    _events.clear();
  }

  List<BehaviorEvent> of(String userId) =>
      _events.where((e) => e.userId == userId).toList();

  void record({
    required String userId,
    required BehaviorType type,
    Product? product,
    ProductCategory? category,
    String? searchQuery,
  }) {
    final event = BehaviorEvent(
      userId: userId,
      type: type,
      productId: product?.id,
      category: product?.category ?? category,
      price: product?.discountPrice,
      searchQuery: searchQuery,
      occurredAt: DateTime.now(),
    );
    if (AppData.useFirestore) {
      // 구독으로 바로 들어옴
      AppData.write('행동 기록', () => _col.add(event.toMap()));
    } else {
      _events.add(event);
    }
  }
}
