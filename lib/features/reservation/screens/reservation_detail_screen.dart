import 'dart:async';

import 'package:flutter/material.dart';

import 'package:mp_agency/core/theme/app_theme.dart';
import 'package:mp_agency/core/utils/formatters.dart';
import 'package:mp_agency/features/reservation/models/reservation.dart';
import 'package:mp_agency/features/reservation/screens/pickup_complete_screen.dart';
import 'package:mp_agency/features/reservation/services/reservation_service.dart';
import 'package:mp_agency/features/reservation/widgets/reservation_ticket_card.dart';

/// 예약 상세: 픽업 번호 카드 · 픽업 안내 · 예약 취소
class ReservationDetailScreen extends StatefulWidget {
  const ReservationDetailScreen({super.key, required this.reservation});

  final Reservation reservation;

  @override
  State<ReservationDetailScreen> createState() =>
      _ReservationDetailScreenState();
}

class _ReservationDetailScreenState extends State<ReservationDetailScreen> {
  late Reservation _r = widget.reservation;
  bool _cancelling = false;
  bool _pickingUp = false;
  StreamSubscription<Reservation?>? _sub;

  @override
  void initState() {
    super.initState();
    // 판매자가 수령 확인하면 바로 반영
    _sub = ReservationService.instance.watchById(_r.id).listen((r) {
      if (r != null && mounted) setState(() => _r = r);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _pickup() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cream,
        title: Text('음식을 받으셨나요?', style: AppFonts.display(size: 20)),
        content: Text(
          '${_r.product.storeName}에서 ${_r.product.name} ${_r.quantity}개를 '
          '받았다면 수령 완료를 눌러 주세요.',
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('아직이요'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.orange),
            child: const Text('받았어요!'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _pickingUp = true);
    try {
      final done = await ReservationService.instance.markPickedUp(_r.id);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PickupCompleteScreen(reservation: done),
        ),
      );
    } on ReservationException catch (e) {
      if (!mounted) return;
      setState(() => _pickingUp = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _cancel() async {
    final reason = await showDialog<CancelReason>(
      context: context,
      builder: (_) => _CancelDialog(reservation: _r),
    );
    if (reason == null || !mounted) return;

    setState(() => _cancelling = true);
    try {
      final updated = await ReservationService.instance.cancel(
        _r.id,
        reason: reason,
      );
      if (!mounted) return;
      setState(() {
        _r = updated;
        _cancelling = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            updated.refundAmount > 0
                ? '예약을 취소했어요. ${formatWon(updated.refundAmount)} 환불돼요.'
                : '예약을 취소했어요. (${reason.refundLabel})',
          ),
        ),
      );
    } on ReservationException catch (e) {
      if (!mounted) return;
      setState(() => _cancelling = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final status = _r.displayStatus(now);

    return Scaffold(
      appBar: AppBar(title: const Text('예약 상세')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(
            _headline(status),
            style: AppFonts.display(size: 24, height: 1.3),
          ),
          const SizedBox(height: 4),
          Text(
            '${formatClock(_r.reservedAt, now: now)} 예약',
            style: const TextStyle(fontSize: 13, color: AppColors.subText),
          ),
          const SizedBox(height: 16),
          ReservationTicketCard(reservation: _r),
          const SizedBox(height: 20),
          if (status.isActive) PickupChecklist(reservation: _r),
        ],
      ),
      bottomNavigationBar: status.isActive
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton.icon(
                      onPressed: _pickingUp || _cancelling ? null : _pickup,
                      icon: _pickingUp
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_rounded),
                      label: const Text('음식 받았어요 · 수령 완료'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _cancelling || _pickingUp ? null : _cancel,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.subText,
                        minimumSize: const Size.fromHeight(46),
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _cancelling
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('예약 취소하기'),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  String _headline(ReservationStatus status) => switch (status) {
    ReservationStatus.reserved => '픽업을 기다리고 있어요!',
    ReservationStatus.pickedUp => '살렸다. 그리고 다먹었다. 🍽️',
    ReservationStatus.cancelled => '취소된 예약이에요.',
    ReservationStatus.expired => '픽업 시간이 지났어요.',
  };
}

/// 취소 사유 고르기 (RSV-005 환불 기준 안내)
class _CancelDialog extends StatefulWidget {
  const _CancelDialog({required this.reservation});

  final Reservation reservation;

  @override
  State<_CancelDialog> createState() => _CancelDialogState();
}

class _CancelDialogState extends State<_CancelDialog> {
  /// 구매자가 고를 수 있는 사유
  static const _reasons = [
    CancelReason.customerSimple,
    CancelReason.productIssue,
  ];

  CancelReason _reason = CancelReason.customerSimple;

  @override
  Widget build(BuildContext context) {
    final r = widget.reservation;
    final refund = _reason.fullRefund ? r.totalPrice : 0;
    return AlertDialog(
      backgroundColor: AppColors.cream,
      scrollable: true,
      title: Text('예약을 취소할까요?', style: AppFonts.display(size: 20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${r.product.name} ${r.quantity}개 예약이 취소되고, '
            '다른 사람이 구할 수 있게 다시 판매돼요.',
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 12),
          const Text(
            '취소 사유',
            style: TextStyle(fontSize: 12, color: AppColors.subText),
          ),
          RadioGroup<CancelReason>(
            groupValue: _reason,
            onChanged: (v) => setState(() => _reason = v ?? _reason),
            child: Column(
              children: [
                for (final reason in _reasons)
                  RadioListTile<CancelReason>(
                    value: reason,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    activeColor: AppColors.orange,
                    title: Text(reason.label),
                    subtitle: Text(reason.refundLabel),
                  ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '환불 예정 금액 ${formatWon(refund)}',
              style: AppFonts.display(
                size: 15,
                color: refund > 0 ? AppColors.deepGreen : AppColors.urgent,
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '판매자 사정·시스템 오류·상품 하자는 전액 환불, 단순 변심과 노쇼는 환불이 어려워요. '
            '(지금은 테스트 결제라 실제로 나간 돈은 없어요)',
            style: TextStyle(fontSize: 11, color: AppColors.subText),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('그냥 둘게요'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _reason),
          style: TextButton.styleFrom(foregroundColor: AppColors.urgent),
          child: const Text('예약 취소'),
        ),
      ],
    );
  }
}
