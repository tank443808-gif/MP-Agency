import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'package:mp_agency/core/data/app_data.dart';
import 'package:mp_agency/core/utils/formatters.dart';
import 'package:mp_agency/features/favorite/services/favorite_service.dart';
import 'package:mp_agency/features/notification/models/app_notification.dart';
import 'package:mp_agency/features/notification/services/notification_service.dart';
import 'package:mp_agency/features/product/models/product.dart';
import 'package:mp_agency/features/store/models/store.dart';
import 'package:mp_agency/features/store/services/store_service.dart';

/// 재고 부족 등으로 상품을 확보하지 못했을 때
class StockException implements Exception {
  const StockException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// 상품 데이터 처리 (기능명세 HOME-001 목록, SELL-003 등록, SELL-004 수정·종료)
///
/// Firestore 모드: products 컬렉션을 실시간 구독해 사본을 유지 ([bindRemote]).
/// 메모리 모드(미리보기·테스트): 예시 상품으로 시작, 앱을 새로 켜면 초기화.
class ProductService {
  ProductService._();
  static final instance = ProductService._();

  /// 사진은 상품 문서 안에 저장하므로 문서 한도(1MB) 안으로 제한
  static const maxImageBytes = 700 * 1024;

  late final List<Product> _products = AppData.useFirestore
      ? <Product>[]
      : sampleProducts(DateTime.now(), includeEnded: true);
  final _changes = StreamController<void>.broadcast();
  int _seq = 100;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  CollectionReference<Map<String, dynamic>> get _col =>
      AppData.db.collection('products');

  /// Firestore 실시간 구독 시작. 첫 데이터가 오면 완료.
  Future<void> bindRemote() {
    final ready = Completer<void>();
    _sub?.cancel();
    _sub = _col.snapshots().listen(
      (snap) {
        _products
          ..clear()
          ..addAll(snap.docs.map((d) => Product.fromMap(d.id, d.data())));
        _changes.add(null);
        if (!ready.isCompleted) ready.complete();
      },
      onError: (Object e) {
        debugPrint('products 구독 실패: $e');
        if (!ready.isCompleted) ready.complete();
      },
    );
    return ready.future;
  }

  void unbind() {
    _sub?.cancel();
    _sub = null;
  }

  // ───────── 구매자 ─────────

  /// 판매 중인 상품 목록 (마감이 가까운 순). 바뀔 때마다 다시 보내줌.
  /// 영업을 쉬는 매장의 상품은 빠짐.
  Stream<List<Product>> watchOnSale() async* {
    yield onSale();
    await for (final _ in _changes.stream) {
      yield onSale();
    }
  }

  List<Product> onSale() {
    final now = DateTime.now();
    return _products.where((p) {
      final store = StoreService.instance.findById(p.storeId);
      return p.isAvailable(now) && (store?.isOpen ?? true);
    }).toList()..sort((a, b) => a.saleEndAt.compareTo(b.saleEndAt));
  }

  Product? findById(String id) {
    for (final p in _products) {
      if (p.id == id) return p;
    }
    return null;
  }

  // ───────── 판매자 ─────────

  /// 매장의 모든 상품 (판매 중 먼저)
  List<Product> byStore(String storeId) {
    final now = DateTime.now();
    return _products.where((p) => p.storeId == storeId).toList()..sort((a, b) {
      final aa = a.isAvailable(now) ? 0 : 1;
      final bb = b.isAvailable(now) ? 0 : 1;
      if (aa != bb) return aa - bb;
      // 판매 중: 마감이 가까운 순 / 끝난 상품: 최근 것부터
      return aa == 0
          ? a.saleEndAt.compareTo(b.saleEndAt)
          : b.saleEndAt.compareTo(a.saleEndAt);
    });
  }

  Stream<List<Product>> watchByStore(String storeId) async* {
    yield byStore(storeId);
    await for (final _ in _changes.stream) {
      yield byStore(storeId);
    }
  }

  /// 상품 등록 (SELL-003)
  Product add({
    required Store store,
    required String name,
    required ProductCategory category,
    required int originalPrice,
    required int discountPrice,
    required int stock,
    required DateTime saleEndAt,
    String? emoji,
    String? description,
    Uint8List? imageBytes,
    DateTime? pickupStartAt,
    DateTime? pickupEndAt,
  }) {
    _validate(originalPrice, discountPrice, stock);
    _validatePickup(pickupStartAt, pickupEndAt, saleEndAt);
    _validateImage(imageBytes);
    final product = Product(
      id: AppData.useFirestore ? _col.doc().id : 'p${_seq++}',
      storeId: store.id,
      storeName: store.name,
      name: name,
      category: category,
      originalPrice: originalPrice,
      discountPrice: discountPrice,
      stockQuantity: stock,
      initialStock: stock,
      saleEndAt: saleEndAt,
      storeLatitude: store.latitude,
      storeLongitude: store.longitude,
      storeAddress: store.address,
      pickupGuide: store.pickupGuide,
      emoji: emoji,
      imageBytes: imageBytes,
      description: description,
      pickupStartAt: pickupStartAt,
      pickupEndAt: pickupEndAt,
      createdAt: DateTime.now(),
    );
    _products.add(product);
    _changes.add(null);
    AppData.write(
      '상품 등록',
      () => _col.doc(product.id).set({
        ...product.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    );
    _recommendToFans(product);
    return product;
  }

  /// 찜한 손님에게 새 음식 추천 알림 (notifications.type = RECOMMENDATION)
  Future<void> _recommendToFans(Product p) async {
    final fans = await FavoriteService.instance.fansOf(p.storeId);
    for (final userId in fans) {
      NotificationService.instance.send(
        userId: userId,
        type: NotificationType.recommendation,
        title: '찜한 ${p.storeName}에 새 음식이 올라왔어요',
        message:
            '${p.name} ${p.discountRate}% 할인 · ${formatWon(p.discountPrice)} · '
            '${formatClock(p.saleEndAt)}까지',
        referenceId: p.id,
      );
    }
  }

  /// 상품 수정 (SELL-004). 재고를 늘리면 처음 수량도 맞춰 늘려줌.
  Product update(Product updated) {
    _validate(
      updated.originalPrice,
      updated.discountPrice,
      updated.stockQuantity,
    );
    _validatePickup(
      updated.pickupStartAt,
      updated.pickupEndAt,
      updated.saleEndAt,
    );
    final i = _products.indexWhere((p) => p.id == updated.id);
    if (i < 0) throw const StockException('상품을 찾을 수 없어요.');
    final old = _products[i];
    final added = updated.stockQuantity - old.stockQuantity;
    final fixed = updated.copyWith(
      initialStock: old.totalStock + (added > 0 ? added : 0),
      status: updated.status == ProductStatus.ended
          ? ProductStatus.ended
          : (updated.stockQuantity > 0
                ? ProductStatus.onSale
                : ProductStatus.soldOut),
    );
    _validateImage(fixed.imageBytes);
    _products[i] = fixed;
    _changes.add(null);
    AppData.write('상품 수정', () {
      final data = {
        ...fixed.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      // 사진을 지웠으면 문서에서도 지움
      if (fixed.imageBytes == null) data['imageBytes'] = FieldValue.delete();
      return _col.doc(fixed.id).set(data, SetOptions(merge: true));
    });
    return fixed;
  }

  /// 판매 종료 (SELL-004). 남은 재고는 폐기로 집계됨.
  void endSale(String productId) {
    final i = _products.indexWhere((p) => p.id == productId);
    if (i < 0) return;
    _products[i] = _products[i].copyWith(status: ProductStatus.ended);
    _changes.add(null);
    AppData.write(
      '판매 종료',
      () => _col.doc(productId).update({
        'status': ProductStatus.ended.code,
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    );
  }

  /// 매장 정보가 바뀌면 그 매장 상품의 매장 정보도 갱신
  void syncStore(Store store) {
    final ids = <String>[];
    for (var i = 0; i < _products.length; i++) {
      if (_products[i].storeId == store.id) {
        _products[i] = _products[i].copyWith(
          storeName: store.name,
          storeAddress: store.address,
          pickupGuide: store.pickupGuide,
        );
        ids.add(_products[i].id);
      }
    }
    _changes.add(null);
    AppData.write('상품 매장 정보 갱신', () async {
      final batch = AppData.db.batch();
      for (final id in ids) {
        batch.update(_col.doc(id), {
          'storeName': store.name,
          'storeAddress': store.address,
          'pickupGuide': store.pickupGuide,
        });
      }
      await batch.commit();
    });
  }

  void _validateImage(Uint8List? bytes) {
    if (bytes != null && bytes.length > maxImageBytes) {
      throw const StockException('사진이 너무 커요. 더 작은 사진을 골라 주세요.');
    }
  }

  void _validatePickup(DateTime? start, DateTime? end, DateTime saleEnd) {
    if (start != null && end != null && !end.isAfter(start)) {
      throw const StockException('픽업 종료는 픽업 시작보다 늦어야 해요.');
    }
    if (end != null && end.isBefore(saleEnd)) {
      throw const StockException('픽업 종료는 판매 종료 이후여야 해요.');
    }
  }

  void _validate(int original, int discount, int stock) {
    if (original <= 0) throw const StockException('정가를 입력해 주세요.');
    if (discount < 0 || discount >= original) {
      throw const StockException('할인가는 정가보다 낮아야 해요.');
    }
    if (stock < 0) throw const StockException('수량은 0개 이상이어야 해요.');
  }

  // ───────── 예약 연동 (메모리 모드. Firestore 모드는 예약 서비스의 트랜잭션이 처리) ─────────

  /// 재고 확보 (기능명세 RSV-002 재고 검증). 성공하면 재고가 줄어든 상품을 돌려줌.
  Product takeStock(String productId, int quantity) {
    final i = _products.indexWhere((p) => p.id == productId);
    if (i < 0) throw const StockException('상품을 찾을 수 없어요.');
    final p = _products[i];
    if (!p.isAvailable(DateTime.now())) {
      throw const StockException('판매가 끝난 상품이에요.');
    }
    if (p.stockQuantity < quantity) {
      throw StockException('남은 수량이 ${p.stockQuantity}개뿐이에요.');
    }
    final updated = p.copyWithStock(p.stockQuantity - quantity);
    _products[i] = updated;
    _changes.add(null);
    return updated;
  }

  /// 예약 취소 등으로 재고 되돌리기
  void restoreStock(String productId, int quantity) {
    final i = _products.indexWhere((p) => p.id == productId);
    if (i < 0) return;
    _products[i] = _products[i].copyWithStock(
      _products[i].stockQuantity + quantity,
    );
    _changes.add(null);
  }

  // ───────── 예시 데이터 ─────────

  /// 예시 상품. Firestore가 비었을 때도 이 데이터로 채움 ([idPrefix]로 새 ID).
  List<Product> sampleProducts(
    DateTime now, {
    String idPrefix = '',
    bool includeEnded = false,
  }) {
    Product make(
      String id,
      String storeId,
      String name,
      String emoji,
      ProductCategory category,
      int original,
      int discount,
      int stock,
      Duration endIn,
      String description, {
      int? initial,
      ProductStatus status = ProductStatus.onSale,
    }) {
      final store =
          StoreService.instance.findById(storeId) ??
          StoreService.sampleStores.firstWhere((s) => s.id == storeId);
      return Product(
        id: '$idPrefix$id',
        storeId: storeId,
        storeName: store.name,
        name: name,
        emoji: emoji,
        category: category,
        originalPrice: original,
        discountPrice: discount,
        stockQuantity: stock,
        initialStock: initial ?? stock,
        saleEndAt: now.add(endIn),
        storeLatitude: store.latitude,
        storeLongitude: store.longitude,
        storeAddress: store.address,
        pickupGuide: store.pickupGuide,
        description: description,
        createdAt: now.subtract(const Duration(hours: 3)),
        status: status,
      );
    }

    return [
      make(
        'p1',
        's1',
        '버터 크루아상',
        '🥐',
        ProductCategory.bakery,
        3500,
        1500,
        3,
        const Duration(minutes: 48),
        '오늘 아침 구운 버터 크루아상이에요. 겉은 바삭, 속은 촉촉해요. 오늘 안에 드시면 가장 맛있어요.',
        initial: 5,
      ),
      make(
        'p2',
        's2',
        '햄에그 샌드위치',
        '🥪',
        ProductCategory.convenience,
        5000,
        2000,
        2,
        const Duration(hours: 1, minutes: 12),
        '햄과 계란이 듬뿍 들어간 샌드위치. 유통기한이 오늘까지라 반값 이하로 내놨어요.',
      ),
      make(
        'p3',
        's2',
        '참치 삼각김밥',
        '🍙',
        ProductCategory.convenience,
        1700,
        800,
        5,
        const Duration(hours: 2, minutes: 3),
        '든든한 참치마요 삼각김밥. 간단한 한 끼로 딱이에요.',
      ),
      make(
        'p4',
        's3',
        '아이스 아메리카노 + 머핀',
        '🧁',
        ProductCategory.cafe,
        6500,
        3000,
        4,
        const Duration(hours: 1, minutes: 35),
        '오늘 만든 블루베리 머핀과 아이스 아메리카노 세트예요.',
      ),
      make(
        'p5',
        's4',
        '제육 도시락',
        '🍱',
        ProductCategory.meal,
        6900,
        3500,
        2,
        const Duration(minutes: 27),
        '매콤한 제육볶음에 반찬 3가지가 들어간 도시락이에요. 데워 드시면 더 맛있어요.',
      ),
      make(
        'p6',
        's1',
        '통밀 식빵',
        '🍞',
        ProductCategory.bakery,
        4800,
        2400,
        1,
        const Duration(hours: 2, minutes: 40),
        '통밀 100%로 구운 담백한 식빵이에요. 토스트로 드셔도 좋아요.',
        initial: 2,
      ),
      make(
        'p7',
        's3',
        '말차 롤케이크',
        '🍰',
        ProductCategory.cafe,
        5500,
        2500,
        2,
        const Duration(hours: 3, minutes: 10),
        '부드러운 말차 크림이 가득한 롤케이크 한 조각이에요.',
      ),
      make(
        'p8',
        's4',
        '김치볶음밥',
        '🍳',
        ProductCategory.meal,
        6000,
        2900,
        3,
        const Duration(hours: 1, minutes: 50),
        '계란후라이를 올린 김치볶음밥. 전자레인지에 1분 데워 드세요.',
      ),
      // 판매자 통계용: 어제 끝난 상품 (메모리 모드만)
      if (includeEnded)
        make(
          'p90',
          's1',
          '소금빵',
          '🥖',
          ProductCategory.bakery,
          3000,
          1200,
          1,
          const Duration(hours: -20),
          '어제 마감 할인했던 소금빵이에요.',
          initial: 6,
          status: ProductStatus.ended,
        ),
      if (includeEnded)
        make(
          'p91',
          's1',
          '단팥빵',
          '🍩',
          ProductCategory.bakery,
          2500,
          1000,
          0,
          const Duration(hours: -22),
          '어제 완판된 단팥빵이에요.',
          initial: 4,
          status: ProductStatus.ended,
        ),
    ];
  }
}
