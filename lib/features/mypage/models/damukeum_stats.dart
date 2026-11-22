import 'package:mp_agency/features/reservation/models/reservation.dart';

/// 다먹음 등급 (기능명세 ECO-006)
enum DamukeumGrade {
  sprout('새싹', '🌱', 0),
  saver('알뜰러', '🍀', 25),
  eater('다먹러', '🌳', 50),
  master('다먹음 마스터', '🏆', 80);

  const DamukeumGrade(this.label, this.emoji, this.minScore);
  final String label;
  final String emoji;

  /// 이 등급이 되는 최소 다먹음 지수
  final int minScore;

  static DamukeumGrade of(int score) =>
      values.lastWhere((g) => score >= g.minScore);

  DamukeumGrade? get next =>
      index + 1 < values.length ? values[index + 1] : null;
}

/// 나의 다먹음 기록 (기능명세 ECO-001~005)
///
/// 기획서 수정사항대로 따로 저장하지 않고 예약 기록으로 계산합니다.
class DamukeumStats {
  const DamukeumStats({
    required this.rescuedCount,
    required this.savedAmount,
    required this.pickupCount,
    required this.noShowCount,
  });

  /// 수령 완료한 예약들로 계산
  factory DamukeumStats.from(List<Reservation> reservations, DateTime now) {
    var rescued = 0;
    var saved = 0;
    var pickups = 0;
    var noShows = 0;
    for (final r in reservations) {
      switch (r.displayStatus(now)) {
        case ReservationStatus.pickedUp:
          rescued += r.quantity;
          saved += r.savedAmount;
          pickups++;
        case ReservationStatus.expired:
          noShows++;
        case ReservationStatus.reserved:
        case ReservationStatus.cancelled:
          break;
      }
    }
    return DamukeumStats(
      rescuedCount: rescued,
      savedAmount: saved,
      pickupCount: pickups,
      noShowCount: noShows,
    );
  }

  /// 구한 음식 수 = 폐기 방지 수
  final int rescuedCount;
  final int savedAmount;

  /// 수령 횟수
  final int pickupCount;

  /// 픽업 시간을 놓친 횟수
  final int noShowCount;

  /// 제시간 수령률 (0~1). 기록이 없으면 null.
  double? get onTimeRate {
    final total = pickupCount + noShowCount;
    return total == 0 ? null : pickupCount / total;
  }

  /// 다먹음 지수 0~100 (ECO-005)
  /// 수령 횟수 40 + 절약 금액 25 + 폐기 방지 20 + 제시간 수령 15
  int get score {
    if (pickupCount + noShowCount == 0) return 0;
    final pickups = (pickupCount.clamp(0, 10) / 10) * 40;
    final saved = (savedAmount.clamp(0, 50000) / 50000) * 25;
    final rescued = (rescuedCount.clamp(0, 20) / 20) * 20;
    final onTime = (onTimeRate ?? 0) * 15;
    return (pickups + saved + rescued + onTime).round().clamp(0, 100);
  }

  DamukeumGrade get grade => DamukeumGrade.of(score);

  /// 다음 등급까지 남은 점수 (최고 등급이면 null)
  int? get pointsToNext {
    final next = grade.next;
    return next == null ? null : next.minScore - score;
  }

  /// 다음 등급까지 진행률 0~1
  double get progressToNext {
    final next = grade.next;
    if (next == null) return 1;
    return (score - grade.minScore) / (next.minScore - grade.minScore);
  }
}
