import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'package:mp_agency/core/data/app_data.dart';
import 'package:mp_agency/core/utils/formatters.dart';
import 'package:mp_agency/features/notification/models/app_notification.dart';
import 'package:mp_agency/features/notification/services/notification_service.dart';
import 'package:mp_agency/features/product/models/product.dart';
import 'package:mp_agency/features/product/services/product_service.dart';
import 'package:mp_agency/features/recommendation/services/behavior_service.dart';
import 'package:mp_agency/features/reservation/models/reservation.dart';
import 'package:mp_agency/features/store/services/store_service.dart';

/// 예약을 바꿀 수 없을 때 (이미 취소됨, 픽업 번호 불일치 등)
class ReservationException implements Exception {
  const ReservationException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// 예약 처리 (기능명세 RSV-001 예약, RSV-002 재고 검증, RSV-005 취소·환불,
/// MRSV-001 예약 내역, MRSV-004 수령 확인, NOTI-001 픽업 기한 안내)
///
/// 실제 결제 없이 "테스트 결제 완료"로 처리합니다.
///
/// Firestore 모드: reservations 컬렉션에서 "내 예약"과 "내 매장 예약"을
/// 실시간 구독 ([bindRemote]). 예약·취소는 트랜잭션으로 재고와 함께 처리해서
/// 여러 사람이 동시에 예약해도 재고를 넘지 않음.
/// 메모리 모드(미리보기·테스트): 예시 예약으로 시작, 앱을 새로 켜면 초기화.
class ReservationService {
  ReservationService._();
  static final instance = ReservationService._();

  /// 메모리 모드 저장소
  late final List<Reservation> _memory = AppData.useFirestore
      ? <Reservation>[]
      : _samples();

  /// Firestore 모드 사본: 내 예약 / 내 매장 예약
  final _mine = <String, Reservation>{};
  final _store = <String, Reservation>{};
  final _subs = <StreamSubscription<Object?>>[];

  /// Firestore 모드에서 로그인한 사용자
  String? _uid;

  final _changes = StreamController<void>.broadcast();
  final _random = Random();

  CollectionReference<Map<String, dynamic>> get _col =>
      AppData.db.collection('reservations');

  /// 지금 들고 있는 모든 예약
  List<Reservation> get _reservations =>
      AppData.useFirestore ? {..._store, ..._mine}.values.toList() : _memory;

  /// 실시간 구독 시작: 내가 한 예약 + 내 매장에 들어온 예약
  Future<void> bindRemote(String userId) {
    unbind();
    _uid = userId;
    Future<void> listen(String field, Map<String, Reservation> into) {
      final ready = Completer<void>();
      _subs.add(
        _col
            .where(field, isEqualTo: userId)
            .snapshots()
            .listen(
              (snap) {
                into
                  ..clear()
                  ..addEntries(
                    snap.docs.map(
                      (d) => MapEntry(
                        d.id,
                        Reservation.fromMap(
                          d.id,
                          d.data(),
                          currentProduct: ProductService.instance.findById(
                            d.data()['productId'] as String? ?? '',
                          ),
                        ),
                      ),
                    ),
                  );
                _changes.add(null);
                if (!ready.isCompleted) ready.complete();
              },
              onError: (Object e) {
                debugPrint('reservations($field) 구독 실패: $e');
                if (!ready.isCompleted) ready.complete();
              },
            ),
      );
      return ready.future;
    }

    return Future.wait([
      listen('userId', _mine),
      listen('storeOwnerId', _store),
    ]);
  }

  void unbind() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _mine.clear();
    _store.clear();
    _uid = null;
  }

  // ───────── 구매자 ─────────

  /// 내 예약 목록 (최신순)
  List<Reservation> myReservations(String userId) =>
      _reservations.where((r) => r.userId == userId).toList()
        ..sort((a, b) => b.reservedAt.compareTo(a.reservedAt));

  /// 내 예약 목록을 계속 받아보기 (예약·취소·수령 때마다 새 목록)
  Stream<List<Reservation>> watchMine(String userId) =>
      _watch(() => myReservations(userId));

  Reservation? findById(String id) {
    for (final r in _reservations) {
      if (r.id == id) return r;
    }
    return null;
  }

  Stream<Reservation?> watchById(String id) => _watch(() => findById(id));

  // ───────── 판매자 ─────────

  /// 매장에 들어온 예약 (최신순)
  List<Reservation> byStore(String storeId) =>
      _reservations.where((r) => r.product.storeId == storeId).toList()
        ..sort((a, b) => b.reservedAt.compareTo(a.reservedAt));

  Stream<List<Reservation>> watchByStore(String storeId) =>
      _watch(() => byStore(storeId));

  Stream<T> _watch<T>(T Function() read) async* {
    yield read();
    await for (final _ in _changes.stream) {
      yield read();
    }
  }

  // ───────── 동작 ─────────

  /// 상품 예약. 재고가 부족하면 [StockException].
  Future<Reservation> reserve({
    required String userId,
    required Product product,
    required int quantity,
  }) async {
    if (quantity < 1) throw const StockException('수량을 1개 이상 선택해 주세요.');

    final now = DateTime.now();
    final code = (1000 + _random.nextInt(9000)).toString();
    final mmdd =
        '${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    Reservation build(String id, Product updated) => Reservation(
      id: id,
      reservationNumber: 'DM-$mmdd-$code',
      pickupCode: code,
      userId: userId,
      product: updated,
      quantity: quantity,
      unitOriginalPrice: product.originalPrice,
      unitDiscountPrice: product.discountPrice,
      reservedAt: now,
    );

    final Reservation reservation;
    if (AppData.useFirestore) {
      reservation = await _reserveRemote(product, quantity, build);
    } else {
      // 결제하는 느낌을 주기 위한 짧은 대기 (실제 결제 없음)
      await Future<void>.delayed(const Duration(milliseconds: 700));
      final updated = ProductService.instance.takeStock(product.id, quantity);
      reservation = build('r${now.microsecondsSinceEpoch}', updated);
      _memory.add(reservation);
    }

    BehaviorService.instance.record(
      userId: userId,
      type: BehaviorType.reserve,
      product: product,
    );
    NotificationService.instance.send(
      userId: userId,
      type: NotificationType.reserved,
      title: '예약 완료! 이건 오늘 다먹음.',
      message:
          '${product.storeName} ${product.name} $quantity개 · '
          '${formatClock(product.pickupDeadline)}까지 픽업해 주세요. (픽업 번호 $code)',
      referenceId: reservation.id,
    );
    _notifyOwner(
      product,
      NotificationType.newReservation,
      '새 예약이 들어왔어요',
      '${product.name} $quantity개 · 픽업 번호 $code',
      reservation.id,
    );

    _changes.add(null);
    return reservation;
  }

  /// Firestore 트랜잭션: 상품 재고 확인·차감 + 예약 문서 생성을 한 번에
  Future<Reservation> _reserveRemote(
    Product product,
    int quantity,
    Reservation Function(String id, Product updated) build,
  ) async {
    final productRef = AppData.db.collection('products').doc(product.id);
    final ref = _col.doc();
    final owner = StoreService.instance.findById(product.storeId)?.ownerId;
    String? failure;
    Reservation? created;
    try {
      await AppData.db.runTransaction((tx) async {
        final snap = await tx.get(productRef);
        if (!snap.exists) {
          failure = '상품을 찾을 수 없어요.';
          return;
        }
        final p = Product.fromMap(snap.id, snap.data()!);
        if (!p.isAvailable(DateTime.now())) {
          failure = '판매가 끝난 상품이에요.';
          return;
        }
        if (p.stockQuantity < quantity) {
          failure = '남은 수량이 ${p.stockQuantity}개뿐이에요.';
          return;
        }
        final updated = p.copyWithStock(p.stockQuantity - quantity);
        tx.update(productRef, {
          'stockQuantity': updated.stockQuantity,
          'status': updated.status.code,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        final r = build(ref.id, updated);
        tx.set(ref, {
          ...r.toMap(storeOwnerId: owner),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        created = r;
      });
    } catch (e) {
      debugPrint('예약 트랜잭션 실패: $e');
      throw const StockException('예약하지 못했어요. 잠시 후 다시 시도해 주세요.');
    }
    final reason = failure;
    if (reason != null) throw StockException(reason);
    final r = created!;
    _mine[r.id] = r;
    return r;
  }

  /// Firestore에 저장하는 예약 상태 필드
  Map<String, dynamic> _statusFields(Reservation r) => {
    'status': r.status.code,
    'cancelledAt': AppData.ts(r.cancelledAt),
    'pickedUpAt': AppData.ts(r.pickedUpAt),
    'expiredAt': AppData.ts(r.expiredAt),
    'cancelReason': r.cancelReason?.code,
    'pickupReminded': r.pickupReminded,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  /// 구매자 예약 취소 (RSV-005). 재고를 되돌림.
  /// 환불: 단순 변심 → 환불 불가, 상품 하자·정보 불일치 → 전액 환불.
  Future<Reservation> cancel(
    String reservationId, {
    CancelReason reason = CancelReason.customerSimple,
  }) async {
    final r = _activeOrThrow(reservationId);
    await Future<void>.delayed(const Duration(milliseconds: 400));

    final cancelled = _cancel(r, reason);
    _notifyOwner(
      r.product,
      NotificationType.cancelled,
      '손님이 예약을 취소했어요',
      '${r.product.name} ${r.quantity}개 (픽업 번호 ${r.pickupCode}) · '
          '사유: ${reason.label} · 재고가 다시 늘었어요.',
      r.id,
    );
    _changes.add(null);
    return cancelled;
  }

  /// 판매자 예약 취소 (품절·매장 사정 등). 판매자 귀책이라 전액 환불.
  Future<Reservation> cancelBySeller(String reservationId) async {
    final r = _activeOrThrow(reservationId);
    await Future<void>.delayed(const Duration(milliseconds: 400));

    final cancelled = _cancel(r, CancelReason.seller);
    NotificationService.instance.send(
      userId: r.userId,
      type: NotificationType.cancelled,
      title: '매장 사정으로 예약이 취소됐어요',
      message:
          '${r.product.storeName} ${r.product.name} ${r.quantity}개 · '
          '${formatWon(r.totalPrice)} 전액 환불돼요. 죄송해요!',
      referenceId: r.id,
    );
    _changes.add(null);
    return cancelled;
  }

  Reservation _cancel(Reservation r, CancelReason reason) {
    final cancelled = r.copyWith(
      status: ReservationStatus.cancelled,
      cancelledAt: DateTime.now(),
      cancelReason: reason,
    );
    if (!AppData.useFirestore) {
      _replace(cancelled);
      ProductService.instance.restoreStock(r.product.id, r.quantity);
      return cancelled;
    }
    _setLocal(cancelled);
    // 트랜잭션: 예약 취소 + 재고 되돌리기
    AppData.write('예약 취소', () async {
      final productRef = AppData.db.collection('products').doc(r.product.id);
      await AppData.db.runTransaction((tx) async {
        final snap = await tx.get(productRef);
        if (snap.exists) {
          final p = Product.fromMap(snap.id, snap.data()!);
          final restored = p.copyWithStock(p.stockQuantity + r.quantity);
          tx.update(productRef, {
            'stockQuantity': restored.stockQuantity,
            'status': restored.status.code,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        tx.update(_col.doc(r.id), _statusFields(cancelled));
      });
    });
    return cancelled;
  }

  /// 픽업 마감 확인 (NOTI-001 픽업 기한 안내). 화면이 1분마다 부름.
  /// - 마감 30분 전: 손님에게 알림 1번
  /// - 마감이 지남: 노쇼로 만료 처리(환불 불가), 손님·사장님에게 알림
  void checkDeadlines([DateTime? at]) {
    final now = at ?? DateTime.now();
    var changed = false;
    for (final r in List.of(_reservations)) {
      if (r.status != ReservationStatus.reserved) continue;
      final left = r.pickupDeadline.difference(now);

      // Firestore 모드: 손님·사장님 기기가 같은 예약을 동시에 처리하지 않게
      // 손님 기기가 처리하고, 손님이 앱을 안 켰으면 사장님 기기가 마감 5분 뒤 처리
      if (AppData.useFirestore &&
          r.userId != _uid &&
          left > const Duration(minutes: -5)) {
        continue;
      }

      if (left.isNegative) {
        _replace(
          r.copyWith(
            status: ReservationStatus.expired,
            expiredAt: now,
            cancelReason: CancelReason.noShow,
          ),
        );
        NotificationService.instance.send(
          userId: r.userId,
          type: NotificationType.noShow,
          title: '픽업 시간이 지났어요',
          message:
              '${r.product.storeName} ${r.product.name} 예약이 만료됐어요. '
              '노쇼는 환불이 어려워요.',
          referenceId: r.id,
        );
        _notifyOwner(
          r.product,
          NotificationType.noShow,
          '노쇼 예약이 있어요',
          '${r.product.name} ${r.quantity}개 (픽업 번호 ${r.pickupCode})를 '
              '받아가지 않았어요. 폐기로 집계돼요.',
          r.id,
        );
        changed = true;
      } else if (!r.pickupReminded && left.inMinutes < 30) {
        _replace(r.copyWith(pickupReminded: true));
        NotificationService.instance.send(
          userId: r.userId,
          type: NotificationType.pickupReminder,
          title: '픽업 마감 ${left.inMinutes + 1}분 전이에요!',
          message:
              '${r.product.storeName}에서 ${r.product.name} ${r.quantity}개를 '
              '받아 가세요. (픽업 번호 ${r.pickupCode})',
          referenceId: r.id,
        );
        changed = true;
      }
    }
    if (changed) _changes.add(null);
  }

  /// 수령 완료 (MRSV-004).
  /// 판매자가 확인할 때는 [pickupCode]를 넣어 번호가 맞는지 확인함.
  Future<Reservation> markPickedUp(
    String reservationId, {
    String? pickupCode,
  }) async {
    final r = _activeOrThrow(reservationId);
    if (pickupCode != null && pickupCode.trim() != r.pickupCode) {
      throw const ReservationException('픽업 번호가 맞지 않아요.');
    }
    if (r.product.pickupNotStarted(DateTime.now())) {
      throw ReservationException(
        '아직 픽업 시간 전이에요. ${formatClock(r.product.pickupStartAt!)}부터 받을 수 있어요.',
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 400));

    final done = r.copyWith(
      status: ReservationStatus.pickedUp,
      pickedUpAt: DateTime.now(),
    );
    _replace(done);

    BehaviorService.instance.record(
      userId: r.userId,
      type: BehaviorType.pickup,
      product: r.product,
    );
    NotificationService.instance.send(
      userId: r.userId,
      type: NotificationType.pickedUp,
      title: '살렸다. 그리고 다먹었다. 🍽️',
      message:
          '${r.product.name} ${r.quantity}개를 구했어요 · '
          '${formatWon(r.savedAmount)} 절약!',
      referenceId: r.id,
    );
    _changes.add(null);
    return done;
  }

  Reservation _activeOrThrow(String id) {
    final r = findById(id);
    if (r == null) throw const ReservationException('예약을 찾을 수 없어요.');
    if (r.displayStatus(DateTime.now()) != ReservationStatus.reserved) {
      throw const ReservationException('이미 끝난 예약이에요.');
    }
    return r;
  }

  /// 예약 상태 바꾸기: 사본을 바꾸고 Firestore에도 저장
  void _replace(Reservation r) {
    _setLocal(r);
    AppData.write('예약 상태 저장', () => _col.doc(r.id).update(_statusFields(r)));
  }

  void _setLocal(Reservation r) {
    if (!AppData.useFirestore) {
      final i = _memory.indexWhere((x) => x.id == r.id);
      if (i >= 0) _memory[i] = r;
      return;
    }
    if (_mine.containsKey(r.id)) _mine[r.id] = r;
    if (_store.containsKey(r.id)) _store[r.id] = r;
  }

  void _notifyOwner(
    Product product,
    NotificationType type,
    String title,
    String message,
    String referenceId,
  ) {
    final owner = StoreService.instance.findById(product.storeId)?.ownerId;
    if (owner == null) return;
    NotificationService.instance.send(
      userId: owner,
      type: type,
      title: title,
      message: message,
      referenceId: referenceId,
    );
  }

  // ───────── 예시 데이터 (판매자 화면용, 다른 손님의 예약) ─────────

  List<Reservation> _samples() {
    final now = DateTime.now();
    Reservation? make(
      String id,
      String productId,
      int qty,
      String code,
      Duration ago,
      ReservationStatus status,
    ) {
      final p = ProductService.instance.findById(productId);
      if (p == null) return null;
      final at = now.subtract(ago);
      return Reservation(
        id: id,
        reservationNumber: 'DM-SAMPLE-$code',
        pickupCode: code,
        userId: 'sample-customer',
        product: p,
        quantity: qty,
        unitOriginalPrice: p.originalPrice,
        unitDiscountPrice: p.discountPrice,
        reservedAt: at,
        status: status,
        pickedUpAt: status == ReservationStatus.pickedUp
            ? at.add(const Duration(minutes: 40))
            : null,
      );
    }

    return [
      make(
        'rs1',
        'p90',
        5,
        '5120',
        const Duration(hours: 22),
        ReservationStatus.pickedUp,
      ),
      make(
        'rs2',
        'p91',
        4,
        '7731',
        const Duration(hours: 23),
        ReservationStatus.pickedUp,
      ),
      make(
        'rs3',
        'p1',
        2,
        '1048',
        const Duration(minutes: 35),
        ReservationStatus.reserved,
      ),
      make(
        'rs4',
        'p6',
        1,
        '3392',
        const Duration(hours: 1),
        ReservationStatus.pickedUp,
      ),
    ].whereType<Reservation>().toList();
  }
}
