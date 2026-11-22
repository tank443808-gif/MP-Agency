import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:mp_agency/core/theme/app_theme.dart';
import 'package:mp_agency/core/utils/formatters.dart';
import 'package:mp_agency/core/widgets/pill_chip.dart';
import 'package:mp_agency/features/product/widgets/product_card.dart';
import 'package:mp_agency/features/reservation/models/reservation.dart';
import 'package:mp_agency/features/reservation/services/reservation_service.dart';
import 'package:mp_agency/features/reservation/widgets/reservation_status_chip.dart';
import 'package:mp_agency/features/store/models/store.dart';

/// 판매자 예약 관리 탭 (기능명세 MRSV-004 수령 확인): "예약된 상품! 여기서 관리해요"
class SellerReservationScreen extends StatefulWidget {
  const SellerReservationScreen({super.key, required this.store});

  final Store store;

  @override
  State<SellerReservationScreen> createState() =>
      _SellerReservationScreenState();
}

enum _Filter {
  pending('픽업 대기'),
  done('수령 완료'),
  closed('취소'),
  all('전체');

  const _Filter(this.label);
  final String label;
}

class _SellerReservationScreenState extends State<SellerReservationScreen> {
  late final Stream<List<Reservation>> _stream = ReservationService.instance
      .watchByStore(widget.store.id);
  _Filter _filter = _Filter.pending;
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

  bool _match(Reservation r) {
    final s = r.displayStatus(_now);
    return switch (_filter) {
      _Filter.pending => s == ReservationStatus.reserved,
      _Filter.done => s == ReservationStatus.pickedUp,
      _Filter.closed =>
        s == ReservationStatus.cancelled || s == ReservationStatus.expired,
      _Filter.all => true,
    };
  }

  Future<void> _confirm(Reservation r) async {
    final code = await showDialog<String>(
      context: context,
      builder: (_) => _CodeDialog(reservation: r),
    );
    if (code == null || !mounted) return;
    try {
      await ReservationService.instance.markPickedUp(r.id, pickupCode: code);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('수령 확인 완료! ${r.product.name} ${r.quantity}개를 구했어요 🌱'),
        ),
      );
    } on ReservationException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: StreamBuilder<List<Reservation>>(
        stream: _stream,
        builder: (context, snap) {
          final all = snap.data ?? const <Reservation>[];
          final pending = all
              .where((r) => r.displayStatus(_now) == ReservationStatus.reserved)
              .toList();
          final shown = all.where(_match).toList();
          if (_filter == _Filter.pending) {
            shown.sort((a, b) => a.pickupDeadline.compareTo(b.pickupDeadline));
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Text(
                '예약된 상품!\n여기서 관리해요',
                style: AppFonts.display(size: 26, height: 1.3),
              ),
              const SizedBox(height: 4),
              Text(
                '픽업 대기 ${pending.length}건 · 손님이 말하는 픽업 번호로 수령을 확인해요.',
                style: const TextStyle(fontSize: 13, color: AppColors.subText),
              ),
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final f in _Filter.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: PillChip(
                          label: f.label,
                          selected: f == _filter,
                          onTap: () => setState(() => _filter = f),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (shown.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    '해당하는 예약이 없어요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.subText),
                  ),
                ),
              for (final r in shown)
                _SellerReservationTile(
                  reservation: r,
                  now: _now,
                  onConfirm: () => _confirm(r),
                ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.paleGreen,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  '💡 픽업 시간이 지나도록 오지 않은 예약은 자동으로 취소(기한만료)로 바뀌고, '
                  '남은 음식은 폐기로 집계돼요.',
                  style: TextStyle(fontSize: 12, height: 1.5),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SellerReservationTile extends StatelessWidget {
  const _SellerReservationTile({
    required this.reservation,
    required this.now,
    required this.onConfirm,
  });

  final Reservation reservation;
  final DateTime now;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final r = reservation;
    final status = r.displayStatus(now);
    final active = status.isActive;
    final left = r.pickupDeadline.difference(now);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: active
              ? AppColors.orange.withValues(alpha: 0.4)
              : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          ProductThumbnail(product: r.product, size: 56),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${r.product.name} · ${r.quantity}개',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.display(size: 15),
                ),
                Text(
                  '${formatWon(r.totalPrice)} · ${formatClock(r.reservedAt, now: now)} 예약',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.subText,
                  ),
                ),
                if (active)
                  Text(
                    '${formatRemaining(left).replaceAll(' 남음', '')} 안에 픽업',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.urgent,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          active
              ? FilledButton(
                  onPressed: onConfirm,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    textStyle: AppFonts.display(size: 13),
                  ),
                  child: const Text('수령 확인'),
                )
              : ReservationStatusChip(status: status),
        ],
      ),
    );
  }
}

/// 손님이 말한 픽업 번호 4자리 입력
class _CodeDialog extends StatefulWidget {
  const _CodeDialog({required this.reservation});

  final Reservation reservation;

  @override
  State<_CodeDialog> createState() => _CodeDialogState();
}

class _CodeDialogState extends State<_CodeDialog> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.reservation;
    return AlertDialog(
      backgroundColor: AppColors.cream,
      title: Text('픽업 번호 확인', style: AppFonts.display(size: 20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${r.product.name} ${r.quantity}개\n손님이 말하는 4자리 번호를 입력해 주세요.',
            style: const TextStyle(height: 1.5),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _code,
            autofocus: true,
            keyboardType: TextInputType.number,
            maxLength: 4,
            textAlign: TextAlign.center,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: AppFonts.display(size: 28).copyWith(letterSpacing: 8),
            decoration: const InputDecoration(
              counterText: '',
              hintText: '0000',
            ),
            onSubmitted: (v) => Navigator.pop(context, v),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('닫기'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _code.text),
          style: TextButton.styleFrom(foregroundColor: AppColors.orange),
          child: const Text('수령 확인'),
        ),
      ],
    );
  }
}
