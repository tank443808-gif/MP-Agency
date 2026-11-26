// 화면 없이 규칙(계산·정책)만 검사하는 테스트.
// 실행: flutter test test/logic_test.dart
import 'package:flutter_test/flutter_test.dart';

import 'package:mp_agency/features/auth/models/app_user.dart';
import 'package:mp_agency/features/favorite/services/favorite_service.dart';
import 'package:mp_agency/features/home/widgets/quick_filter_chips.dart';
import 'package:mp_agency/features/mypage/models/damukeum_stats.dart';
import 'package:mp_agency/features/notification/models/app_notification.dart';
import 'package:mp_agency/features/notification/services/notification_service.dart';
import 'package:mp_agency/features/product/models/product.dart';
import 'package:mp_agency/features/product/services/product_service.dart';
import 'package:mp_agency/features/reservation/models/reservation.dart';
import 'package:mp_agency/features/reservation/services/reservation_service.dart';
import 'package:mp_agency/features/seller_dashboard/models/seller_stats.dart';
import 'package:mp_agency/features/store/services/store_service.dart';

const _seller = AppUser(
  uid: 'logic-seller',
  email: 's@example.com',
  nickname: '사장님',
  role: UserRole.seller,
  storeName: '로직 테스트 가게',
);

var _seq = 0;

/// 테스트마다 새 상품을 등록 (다른 테스트와 재고가 섞이지 않게)
Product _newProduct({
  int stock = 3,
  Duration endIn = const Duration(hours: 2),
  DateTime? pickupStartAt,
}) {
  final store = StoreService.instance.storeOf(_seller);
  final end = DateTime.now().add(endIn);
  return ProductService.instance.add(
    store: store,
    name: '테스트 빵 ${_seq++}',
    category: ProductCategory.bakery,
    originalPrice: 4000,
    discountPrice: 1500,
    stock: stock,
    saleEndAt: end,
    pickupStartAt: pickupStartAt,
    pickupEndAt: end.add(const Duration(minutes: 10)),
  );
}

List<AppNotification> _notesOf(String userId, NotificationType type) =>
    NotificationService.instance
        .of(userId)
        .where((n) => n.type == type)
        .toList();

void main() {
  group('예약 취소·환불 (RSV-005)', () {
    test('단순 변심 취소는 환불 불가, 재고는 돌아옴', () async {
      final p = _newProduct();
      final r = await ReservationService.instance.reserve(
        userId: 'u-simple',
        product: p,
        quantity: 2,
      );
      expect(ProductService.instance.findById(p.id)!.stockQuantity, 1);

      final c = await ReservationService.instance.cancel(r.id);
      expect(c.status, ReservationStatus.cancelled);
      expect(c.cancelReason, CancelReason.customerSimple);
      expect(c.refundAmount, 0);
      expect(ProductService.instance.findById(p.id)!.stockQuantity, 3);
    });

    test('상품 하자 취소는 전액 환불', () async {
      final r = await ReservationService.instance.reserve(
        userId: 'u-issue',
        product: _newProduct(),
        quantity: 2,
      );
      final c = await ReservationService.instance.cancel(
        r.id,
        reason: CancelReason.productIssue,
      );
      expect(c.refundAmount, 3000);
    });

    test('판매자 취소는 전액 환불 + 손님에게 알림', () async {
      final r = await ReservationService.instance.reserve(
        userId: 'u-seller-cancel',
        product: _newProduct(),
        quantity: 1,
      );
      final c = await ReservationService.instance.cancelBySeller(r.id);
      expect(c.cancelReason, CancelReason.seller);
      expect(c.refundAmount, 1500);
      expect(
        _notesOf('u-seller-cancel', NotificationType.cancelled),
        isNotEmpty,
      );
    });

    test('재고보다 많이 예약하면 실패 (RSV-002)', () async {
      expect(
        () => ReservationService.instance.reserve(
          userId: 'u-over',
          product: _newProduct(stock: 1),
          quantity: 2,
        ),
        throwsA(isA<StockException>()),
      );
    });
  });

  group('픽업 기한 (NOTI-001)', () {
    test('마감 30분 전 알림은 한 번만', () async {
      final r = await ReservationService.instance.reserve(
        userId: 'u-remind',
        product: _newProduct(),
        quantity: 1,
      );
      final almost = r.pickupDeadline.subtract(const Duration(minutes: 20));
      ReservationService.instance.checkDeadlines(almost);
      ReservationService.instance.checkDeadlines(almost);
      expect(
        _notesOf('u-remind', NotificationType.pickupReminder),
        hasLength(1),
      );
    });

    test('마감이 지나면 노쇼로 만료 (환불 불가, expired_at 기록)', () async {
      final r = await ReservationService.instance.reserve(
        userId: 'u-noshow',
        product: _newProduct(),
        quantity: 1,
      );
      ReservationService.instance.checkDeadlines(
        r.pickupDeadline.add(const Duration(minutes: 1)),
      );
      final after = ReservationService.instance.findById(r.id)!;
      expect(after.status, ReservationStatus.expired);
      expect(after.expiredAt, isNotNull);
      expect(after.cancelReason, CancelReason.noShow);
      expect(after.refundAmount, 0);
      expect(_notesOf('u-noshow', NotificationType.noShow), hasLength(1));
    });

    test('픽업 시작 전에는 수령 확인 불가', () async {
      final r = await ReservationService.instance.reserve(
        userId: 'u-early',
        product: _newProduct(
          pickupStartAt: DateTime.now().add(const Duration(hours: 1)),
        ),
        quantity: 1,
      );
      expect(
        () => ReservationService.instance.markPickedUp(r.id),
        throwsA(isA<ReservationException>()),
      );
    });

    test('픽업 종료가 판매 종료보다 이르면 등록 실패', () {
      final store = StoreService.instance.storeOf(_seller);
      final end = DateTime.now().add(const Duration(hours: 2));
      expect(
        () => ProductService.instance.add(
          store: store,
          name: '잘못된 픽업',
          category: ProductCategory.meal,
          originalPrice: 5000,
          discountPrice: 2000,
          stock: 1,
          saleEndAt: end,
          pickupEndAt: end.subtract(const Duration(minutes: 30)),
        ),
        throwsA(isA<StockException>()),
      );
    });
  });

  group('알림 설정·추천 알림', () {
    test('예약 알림을 끄면 예약 완료 알림이 오지 않음', () async {
      NotificationService.instance.setOn(
        'u-muted',
        NotificationGroup.reservation,
        false,
      );
      await ReservationService.instance.reserve(
        userId: 'u-muted',
        product: _newProduct(),
        quantity: 1,
      );
      expect(_notesOf('u-muted', NotificationType.reserved), isEmpty);
    });

    test('찜한 매장에 새 상품이 올라오면 추천 알림', () async {
      final store = StoreService.instance.storeOf(_seller);
      FavoriteService.instance.toggle('u-fan', store.id);
      _newProduct();
      // 찜한 사람 찾기가 비동기라 잠깐 기다림
      await Future<void>.delayed(Duration.zero);
      expect(_notesOf('u-fan', NotificationType.recommendation), isNotEmpty);
    });
  });

  group('매장 위치', () {
    test('매장 위치를 바꾸면 그 매장 상품의 픽업 위치도 바뀜', () {
      final p = _newProduct();
      final store = StoreService.instance.storeOf(_seller);
      final moved = store.copyWith(
        latitude: 37.5,
        longitude: 127.2,
        address: '새 주소 1층',
      );
      StoreService.instance.update(moved);
      ProductService.instance.syncStore(moved);
      final after = ProductService.instance.findById(p.id)!;
      expect(after.storeLatitude, 37.5);
      expect(after.storeLongitude, 127.2);
      expect(after.storeAddress, '새 주소 1층');
      expect(StoreService.instance.findById(store.id)!.latitude, 37.5);
    });
  });

  group('계산', () {
    test('가격 범위 필터 (SRCH-003)', () {
      const r = PriceRange(1000, 3000);
      expect(r.contains(999), isFalse);
      expect(r.contains(1000), isTrue);
      expect(r.contains(3000), isTrue);
      expect(r.contains(3001), isFalse);
      const noCap = PriceRange(5000, PriceRange.ceiling);
      expect(noCap.contains(50000), isTrue);
      expect(noCap.label, '5,000원 이상');
    });

    test('대시보드 기간: 어제 예약은 "오늘"에서 빠짐 (DASH-001)', () {
      final p = _newProduct();
      final now = DateTime.now();
      Reservation res(DateTime at) => Reservation(
        id: 'x${at.microsecondsSinceEpoch}',
        reservationNumber: 'T',
        pickupCode: '0000',
        userId: 'u',
        product: p,
        quantity: 1,
        unitOriginalPrice: 4000,
        unitDiscountPrice: 1500,
        reservedAt: at,
        status: ReservationStatus.pickedUp,
      );
      final list = [res(now), res(now.subtract(const Duration(days: 1)))];
      final today = SellerStats.from(
        products: [p],
        reservations: list,
        now: now,
        period: StatsPeriod.today,
      );
      final all = SellerStats.from(products: [p], reservations: list, now: now);
      expect(today.soldCount, 1);
      expect(all.soldCount, 2);
    });

    test('다먹음 지수·등급 (ECO-005, 006)', () {
      expect(
        const DamukeumStats(
          rescuedCount: 0,
          savedAmount: 0,
          pickupCount: 0,
          noShowCount: 0,
        ).grade,
        DamukeumGrade.sprout,
      );
      const master = DamukeumStats(
        rescuedCount: 20,
        savedAmount: 50000,
        pickupCount: 10,
        noShowCount: 0,
      );
      expect(master.score, 100);
      expect(master.grade, DamukeumGrade.master);
    });
  });
}
