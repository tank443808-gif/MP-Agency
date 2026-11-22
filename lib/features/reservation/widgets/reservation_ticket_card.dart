import 'package:flutter/material.dart';

import 'package:mp_agency/core/theme/app_theme.dart';
import 'package:mp_agency/core/utils/formatters.dart';
import 'package:mp_agency/features/product/widgets/product_card.dart';
import 'package:mp_agency/features/reservation/models/reservation.dart';
import 'package:mp_agency/features/reservation/widgets/reservation_status_chip.dart';

/// 취소 사유. 마감이 지나 노쇼로 보이는 예약은 노쇼로 봄.
CancelReason? _reasonOf(Reservation r) =>
    r.cancelReason ??
    (r.displayStatus(DateTime.now()) == ReservationStatus.expired
        ? CancelReason.noShow
        : null);

/// 영수증 모양 카드: 상품 · 픽업 번호 · 금액
class ReservationTicketCard extends StatelessWidget {
  const ReservationTicketCard({super.key, required this.reservation});

  final Reservation reservation;

  @override
  Widget build(BuildContext context) {
    final r = reservation;
    final p = r.product;
    final active = r.displayStatus(DateTime.now()).isActive;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('오늘의 픽업 정보', style: AppFonts.display(size: 15)),
              const Spacer(),
              ReservationStatusChip(status: r.displayStatus(DateTime.now())),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              ProductThumbnail(product: p, size: 60),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.storeName,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.subText,
                      ),
                    ),
                    Text(
                      '${p.name} · ${r.quantity}개',
                      style: AppFonts.display(size: 17),
                    ),
                    Text(
                      formatWon(r.totalPrice),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.text,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const _DashedLine(),
          const SizedBox(height: 16),
          const Text(
            '픽업 번호',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.subText),
          ),
          Text(
            r.pickupCode,
            textAlign: TextAlign.center,
            style: AppFonts.display(
              size: 56,
              color: active ? AppColors.orange : AppColors.border,
            ).copyWith(letterSpacing: 8),
          ),
          if (!active)
            const Text(
              '이제 사용할 수 없는 번호예요',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.subText),
            ),
          Text(
            '예약 번호 ${r.reservationNumber}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppColors.subText),
          ),
          const SizedBox(height: 16),
          const _DashedLine(),
          const SizedBox(height: 12),
          _Row(label: '픽업 장소', value: p.storeName),
          _Row(
            label: '픽업 시간',
            value: formatTimeRange(r.product.pickupStartAt, r.pickupDeadline),
          ),
          _Row(label: '정가', value: formatWon(r.totalOriginalPrice)),
          _Row(
            label: '다먹음 할인',
            value: '-${formatWon(r.savedAmount)}',
            valueColor: AppColors.urgent,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Text(
                '결제 금액',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
              const Spacer(),
              Text(formatWon(r.totalPrice), style: AppFonts.display(size: 22)),
            ],
          ),
          const Align(
            alignment: Alignment.centerRight,
            child: Text(
              '테스트 결제 · 실제 결제 없음',
              style: TextStyle(fontSize: 11, color: AppColors.subText),
            ),
          ),
          // 취소·노쇼면 사유와 환불 안내 (RSV-005)
          if (_reasonOf(r) != null) ...[
            const SizedBox(height: 8),
            _Row(label: '취소 사유', value: _reasonOf(r)!.label),
            _Row(
              label: '환불',
              value: _reasonOf(r)!.fullRefund
                  ? '${formatWon(r.totalPrice)} 전액 환불'
                  : '환불 불가',
              valueColor: _reasonOf(r)!.fullRefund
                  ? AppColors.deepGreen
                  : AppColors.urgent,
            ),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppColors.subText),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: valueColor ?? AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}

/// 영수증 절취선
class _DashedLine extends StatelessWidget {
  const _DashedLine();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final count = (c.maxWidth / 10).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            count,
            (_) => Container(width: 5, height: 1.5, color: AppColors.border),
          ),
        );
      },
    );
  }
}

/// 픽업 전 확인할 것
class PickupChecklist extends StatelessWidget {
  const PickupChecklist({super.key, required this.reservation});

  final Reservation reservation;

  @override
  Widget build(BuildContext context) {
    final items = [
      '${formatClock(reservation.pickupDeadline)}까지 매장에 방문해 주세요.',
      '매장에서 픽업 번호 ${reservation.pickupCode}을(를) 말해 주세요.',
      '픽업 시간이 지나면 예약이 취소되고 환불이 어려워요.',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('픽업 전에 확인해요', style: AppFonts.display(size: 16)),
        const SizedBox(height: 8),
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.lightGreen,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${i + 1}',
                    style: AppFonts.display(
                      size: 12,
                      color: AppColors.deepGreen,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    items[i],
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
