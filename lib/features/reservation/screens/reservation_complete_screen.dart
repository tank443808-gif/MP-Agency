import 'package:flutter/material.dart';

import 'package:mp_agency/core/theme/app_theme.dart';
import 'package:mp_agency/core/utils/formatters.dart';
import 'package:mp_agency/features/navigation/screens/buyer_main_screen.dart';
import 'package:mp_agency/features/reservation/models/reservation.dart';
import 'package:mp_agency/features/reservation/widgets/reservation_ticket_card.dart';

/// 예약 완료: "예약 완료! 이건 오늘 다먹음."
/// 픽업 번호 · 예약 정보 · 결제 금액 · 픽업 전 안내
class ReservationCompleteScreen extends StatelessWidget {
  const ReservationCompleteScreen({super.key, required this.reservation});

  final Reservation reservation;

  void _goHome(BuildContext context) =>
      Navigator.of(context).popUntil((route) => route.isFirst);

  @override
  Widget build(BuildContext context) {
    final r = reservation;

    return PopScope(
      // 뒤로가기를 눌러도 상세 화면이 아니라 홈으로
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goHome(context);
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('예약 완료'),
          actions: [
            IconButton(
              tooltip: '닫기',
              icon: const Icon(Icons.close_rounded),
              onPressed: () => _goHome(context),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.lightGreen,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: AppColors.deepGreen,
                  size: 32,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '예약 완료!\n이건 오늘 다먹음.',
              style: AppFonts.display(size: 30, height: 1.25),
            ),
            const SizedBox(height: 6),
            const Text(
              '매장에서 아래 픽업 번호를 말해 주세요.',
              style: TextStyle(fontSize: 14, color: AppColors.subText),
            ),
            const SizedBox(height: 18),
            ReservationTicketCard(reservation: r),
            const SizedBox(height: 14),
            _RescueBox(reservation: r),
            const SizedBox(height: 20),
            PickupChecklist(reservation: r),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton(
                  onPressed: () => _goHome(context),
                  child: const Text('홈으로 돌아가기'),
                ),
                TextButton(
                  onPressed: () {
                    BuyerTab.current.value = BuyerTab.reservations;
                    _goHome(context);
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.subText,
                  ),
                  child: const Text('예약 내역 보기'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "버려질 뻔한 음식 N개를 구했어요!"
class _RescueBox extends StatelessWidget {
  const _RescueBox({required this.reservation});

  final Reservation reservation;

  @override
  Widget build(BuildContext context) {
    final r = reservation;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.paleGreen,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.lightGreen),
      ),
      child: Row(
        children: [
          const Text('🌱', style: TextStyle(fontSize: 30)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '버려질 뻔한 음식 ${r.quantity}개를 구했어요!',
                  style: AppFonts.display(size: 16, color: AppColors.deepGreen),
                ),
                const SizedBox(height: 2),
                Text(
                  '💰 ${formatWon(r.savedAmount)} 절약 · 받아가면 다먹음 지수가 올라가요',
                  style: const TextStyle(fontSize: 12, color: AppColors.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
