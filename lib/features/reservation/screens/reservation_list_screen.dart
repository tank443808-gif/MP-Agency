import 'dart:async';

import 'package:flutter/material.dart';

import 'package:mp_agency/core/theme/app_theme.dart';
import 'package:mp_agency/core/utils/formatters.dart';
import 'package:mp_agency/features/reservation/models/reservation.dart';
import 'package:mp_agency/features/reservation/screens/reservation_detail_screen.dart';
import 'package:mp_agency/features/reservation/services/reservation_service.dart';
import 'package:mp_agency/features/reservation/widgets/reservation_list_tile.dart';

/// 예약 내역 탭 (기능명세 MRSV-001): 픽업 대기 / 지난 예약
class ReservationListScreen extends StatefulWidget {
  const ReservationListScreen({
    super.key,
    required this.userId,
    this.onBrowseFood,
  });

  final String userId;

  /// 예약이 없을 때 [음식 보러가기] → 홈 탭으로
  final VoidCallback? onBrowseFood;

  @override
  State<ReservationListScreen> createState() => _ReservationListScreenState();
}

class _ReservationListScreenState extends State<ReservationListScreen> {
  late final Stream<List<Reservation>> _stream = ReservationService.instance
      .watchMine(widget.userId);

  DateTime _now = DateTime.now();
  late final Timer _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(
      const Duration(seconds: 30),
      (_) => setState(() => _now = DateTime.now()),
    );
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  void _open(Reservation r) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReservationDetailScreen(reservation: r),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: StreamBuilder<List<Reservation>>(
        stream: _stream,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snap.data!;
          final active =
              all.where((r) => r.displayStatus(_now).isActive).toList()
                // 픽업 마감이 가까운 것부터
                ..sort((a, b) => a.pickupDeadline.compareTo(b.pickupDeadline));
          final past = all
              .where((r) => !r.displayStatus(_now).isActive)
              .toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Text('예약 내역', style: AppFonts.display(size: 26)),
              const SizedBox(height: 4),
              Text(
                active.isEmpty
                    ? '오늘도 버려질 음식을 구하러 가볼까요?'
                    : '픽업을 기다리는 음식이 ${active.length}건 있어요.',
                style: const TextStyle(fontSize: 13, color: AppColors.subText),
              ),
              const SizedBox(height: 16),
              if (all.isEmpty)
                _EmptyState(onBrowseFood: widget.onBrowseFood)
              else ...[
                _SummaryCard(reservations: all, now: _now),
                const SizedBox(height: 20),
                _SectionTitle(title: '픽업 대기', count: active.length),
                if (active.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      '지금 픽업할 음식이 없어요.',
                      style: TextStyle(color: AppColors.subText),
                    ),
                  ),
                for (final r in active)
                  ReservationListTile(
                    reservation: r,
                    now: _now,
                    onTap: () => _open(r),
                  ),
                if (past.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _SectionTitle(title: '지난 예약', count: past.length),
                  for (final r in past)
                    ReservationListTile(
                      reservation: r,
                      now: _now,
                      onTap: () => _open(r),
                    ),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}

/// 이번에 구한 음식 · 절약 금액 요약 (취소·기한만료는 제외)
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.reservations, required this.now});

  final List<Reservation> reservations;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final counted = reservations.where((r) {
      final s = r.displayStatus(now);
      return s == ReservationStatus.reserved || s == ReservationStatus.pickedUp;
    });
    final food = counted.fold<int>(0, (sum, r) => sum + r.quantity);
    final saved = counted.fold<int>(0, (sum, r) => sum + r.savedAmount);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.paleGreen,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.lightGreen),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Stat(emoji: '🍱', value: '$food개', label: '구출 예정·완료'),
          ),
          Container(width: 1, height: 36, color: AppColors.lightGreen),
          Expanded(
            child: _Stat(emoji: '💰', value: formatWon(saved), label: '절약 금액'),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.emoji, required this.value, required this.label});

  final String emoji;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$emoji $value',
          style: AppFonts.display(size: 18, color: AppColors.deepGreen),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.text),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(title, style: AppFonts.display(size: 18)),
          const SizedBox(width: 6),
          Text(
            '$count',
            style: AppFonts.display(size: 18, color: AppColors.orange),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.onBrowseFood});

  final VoidCallback? onBrowseFood;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: const BoxDecoration(
              color: Color(0xFFFFEDE2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              size: 40,
              color: AppColors.urgent,
            ),
          ),
          const SizedBox(height: 16),
          Text('아직 예약한 음식이 없어요', style: AppFonts.display(size: 20)),
          const SizedBox(height: 6),
          const Text(
            '마감 임박 음식을 예약하면 여기에 모여요.',
            style: TextStyle(color: AppColors.subText),
          ),
          const SizedBox(height: 20),
          if (onBrowseFood != null)
            FilledButton(
              onPressed: onBrowseFood,
              style: FilledButton.styleFrom(minimumSize: const Size(200, 48)),
              child: const Text('마감 임박 음식 보러가기'),
            ),
        ],
      ),
    );
  }
}
