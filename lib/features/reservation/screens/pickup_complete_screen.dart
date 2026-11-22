import 'package:flutter/material.dart';

import 'package:mp_agency/core/theme/app_theme.dart';
import 'package:mp_agency/core/utils/formatters.dart';
import 'package:mp_agency/features/mypage/models/damukeum_stats.dart';
import 'package:mp_agency/features/navigation/screens/buyer_main_screen.dart';
import 'package:mp_agency/features/reservation/models/reservation.dart';
import 'package:mp_agency/features/reservation/services/reservation_service.dart';

/// 수령 완료: "살렸다. 그리고 다먹었다." (기능명세 ECO-001 다먹음 기록)
class PickupCompleteScreen extends StatelessWidget {
  const PickupCompleteScreen({super.key, required this.reservation});

  final Reservation reservation;

  void _close(BuildContext context, {int? tab}) {
    if (tab != null) BuyerTab.current.value = tab;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final r = reservation;
    final stats = DamukeumStats.from(
      ReservationService.instance.myReservations(r.userId),
      DateTime.now(),
    );

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('다먹음 완료'),
        actions: [
          IconButton(
            tooltip: '닫기',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => _close(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: const BoxDecoration(
                    color: AppColors.lightGreen,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.restaurant_rounded,
                    size: 56,
                    color: AppColors.deepGreen,
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.urgent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            '살렸다.\n그리고 다먹었다.',
            textAlign: TextAlign.center,
            style: AppFonts.display(size: 30, height: 1.25),
          ),
          const SizedBox(height: 6),
          Text(
            '${r.product.storeName}의 ${r.product.name} ${r.quantity}개를 구했어요.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppColors.subText),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _BigStat(
                  icon: Icons.savings_outlined,
                  value: formatWon(r.savedAmount),
                  label: '이번에 절약',
                  color: AppColors.peach,
                  fg: AppColors.urgent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _BigStat(
                  icon: Icons.eco_outlined,
                  value: '${r.quantity}개',
                  label: '폐기 방지',
                  color: AppColors.paleGreen,
                  fg: AppColors.deepGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Text(stats.grade.emoji, style: const TextStyle(fontSize: 30)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '다먹음 지수 ${stats.score}점 · ${stats.grade.label}',
                        style: AppFonts.display(size: 16),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '지금까지 ${stats.rescuedCount}개를 구하고 '
                        '${formatWon(stats.savedAmount)}을 아꼈어요.',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
                onPressed: () => _close(context, tab: BuyerTab.my),
                child: const Text('나의 다먹음 보기'),
              ),
              TextButton(
                onPressed: () => _close(context, tab: BuyerTab.home),
                style: TextButton.styleFrom(foregroundColor: AppColors.subText),
                child: const Text('또 구하러 가기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BigStat extends StatelessWidget {
  const _BigStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.fg,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: fg),
          const SizedBox(height: 8),
          Text(value, style: AppFonts.display(size: 22, color: fg)),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
