import 'package:mp_agency/features/product/models/product.dart';
import 'package:mp_agency/features/reservation/models/reservation.dart';

/// 대시보드 기간
enum StatsPeriod {
  today('오늘'),
  week('이번 주'),
  month('이번 달'),
  all('전체');

  const StatsPeriod(this.label);
  final String label;

  /// 기간 시작 시각 (전체면 null)
  DateTime? since(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return switch (this) {
      StatsPeriod.today => today,
      StatsPeriod.week => today.subtract(Duration(days: now.weekday - 1)),
      StatsPeriod.month => DateTime(now.year, now.month),
      StatsPeriod.all => null,
    };
  }
}

/// 판매자 성과 (기능명세 DASH-001 판매 대시보드, DASH-005 폐기 감소 통계)
///
/// 상품·예약 기록으로 계산합니다 (따로 저장하지 않음).
class SellerStats {
  const SellerStats({
    required this.registeredCount,
    required this.soldCount,
    required this.wastedCount,
    required this.onSaleCount,
    required this.recoveredRevenue,
    required this.pendingPickupCount,
    required this.todayRevenue,
  });

  factory SellerStats.from({
    required List<Product> products,
    required List<Reservation> reservations,
    required DateTime now,
    StatsPeriod period = StatsPeriod.all,
  }) {
    // 기간 안에 판매한 상품·들어온 예약만 집계
    final since = period.since(now);
    if (since != null) {
      products = products.where((p) => !p.saleEndAt.isBefore(since)).toList();
      reservations = reservations
          .where((r) => !r.reservedAt.isBefore(since))
          .toList();
    }
    var registered = 0;
    var wasted = 0;
    var onSale = 0;
    for (final p in products) {
      registered += p.totalStock;
      if (p.isFinished(now)) {
        wasted += p.stockQuantity; // 판매가 끝났는데 남은 것 = 폐기
      } else {
        onSale += p.stockQuantity;
      }
    }

    var sold = 0;
    var revenue = 0;
    var today = 0;
    var pending = 0;
    for (final r in reservations) {
      final s = r.displayStatus(now);
      if (s == ReservationStatus.cancelled) continue;
      if (s == ReservationStatus.expired) {
        // 노쇼는 이미 결제됐으므로 매출로 보지만, 음식은 폐기됨
        wasted += r.quantity;
        revenue += r.totalPrice;
        continue;
      }
      sold += r.quantity;
      revenue += r.totalPrice;
      if (_sameDay(r.reservedAt, now)) today += r.totalPrice;
      if (s == ReservationStatus.reserved) pending++;
    }

    return SellerStats(
      registeredCount: registered,
      soldCount: sold,
      wastedCount: wasted,
      onSaleCount: onSale,
      recoveredRevenue: revenue,
      pendingPickupCount: pending,
      todayRevenue: today,
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// 등록한 총 수량
  final int registeredCount;

  /// 판매(예약·수령)된 수량
  final int soldCount;

  /// 폐기된 수량 (판매 종료 후 남은 재고 + 노쇼)
  final int wastedCount;

  /// 지금 판매 중인 재고
  final int onSaleCount;

  /// 다먹음으로 회수한 매출
  final int recoveredRevenue;
  final int todayRevenue;

  /// 픽업을 기다리는 예약 수
  final int pendingPickupCount;

  /// 폐기 감소율 = 판매 / (판매 + 폐기). 기록이 없으면 null.
  double? get wasteReductionRate {
    final total = soldCount + wastedCount;
    return total == 0 ? null : soldCount / total;
  }
}
