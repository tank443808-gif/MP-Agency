import 'package:flutter/material.dart';

import 'package:mp_agency/core/theme/app_theme.dart';
import 'package:mp_agency/core/utils/formatters.dart';
import 'package:mp_agency/features/product/widgets/product_card.dart';
import 'package:mp_agency/features/reservation/models/reservation.dart';
import 'package:mp_agency/features/reservation/widgets/reservation_status_chip.dart';

/// 예약 내역 한 줄: 그림 · 매장 · 상품×수량 · 금액 · 상태
/// 픽업 대기 중이면 픽업 번호와 남은 시간도 보여줌.
class ReservationListTile extends StatelessWidget {
  const ReservationListTile({
    super.key,
    required this.reservation,
    required this.now,
    this.onTap,
  });

  final Reservation reservation;
  final DateTime now;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final r = reservation;
    final status = r.displayStatus(now);
    final active = status.isActive;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        elevation: active ? 3 : 0,
        shadowColor: AppColors.shadow,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Opacity(
            opacity: active ? 1 : 0.7,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      ProductThumbnail(product: r.product, size: 64),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    r.product.storeName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.subText,
                                    ),
                                  ),
                                ),
                                ReservationStatusChip(status: status),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${r.product.name} · ${r.quantity}개',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppFonts.display(size: 16),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${formatWon(r.totalPrice)} · '
                              '${formatWon(r.savedAmount)} 절약',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.text,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (active) ...[
                    const SizedBox(height: 12),
                    _PickupStrip(reservation: r, now: now),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 픽업 대기 중일 때: [픽업 번호 1048] [⏰ 32분 안에 픽업]
class _PickupStrip extends StatelessWidget {
  const _PickupStrip({required this.reservation, required this.now});

  final Reservation reservation;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final left = reservation.pickupDeadline.difference(now);
    final urgent = left.inMinutes < 60;
    final color = urgent ? AppColors.urgent : AppColors.orange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Text(
            '픽업 번호',
            style: TextStyle(fontSize: 12, color: AppColors.subText),
          ),
          const SizedBox(width: 6),
          Text(
            reservation.pickupCode,
            style: AppFonts.display(
              size: 18,
              color: AppColors.orange,
            ).copyWith(letterSpacing: 2),
          ),
          const Spacer(),
          Icon(Icons.schedule, size: 14, color: color),
          const SizedBox(width: 3),
          Text(
            '${formatRemaining(left).replaceAll(' 남음', '')} 안에 픽업',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
