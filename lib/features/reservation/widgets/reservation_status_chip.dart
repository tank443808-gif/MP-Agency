import 'package:flutter/material.dart';

import 'package:mp_agency/core/theme/app_theme.dart';
import 'package:mp_agency/features/reservation/models/reservation.dart';

/// 예약 상태 뱃지: 예약됨(오렌지) · 수령완료(연두) · 취소됨/기한만료(회색)
class ReservationStatusChip extends StatelessWidget {
  const ReservationStatusChip({super.key, required this.status});

  final ReservationStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      ReservationStatus.reserved => (AppColors.peach, AppColors.urgent),
      ReservationStatus.pickedUp => (AppColors.lightGreen, AppColors.deepGreen),
      ReservationStatus.cancelled ||
      ReservationStatus.expired => (const Color(0xFFEDE7E1), AppColors.subText),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(status.label, style: AppFonts.display(size: 12, color: fg)),
    );
  }
}
