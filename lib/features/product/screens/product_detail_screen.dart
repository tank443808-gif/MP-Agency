import 'dart:async';

import 'package:flutter/material.dart';

import 'package:mp_agency/core/theme/app_theme.dart';
import 'package:mp_agency/core/utils/formatters.dart';
import 'package:mp_agency/features/product/models/product.dart';
import 'package:mp_agency/features/product/widgets/pickup_info_card.dart';
import 'package:mp_agency/features/product/services/product_service.dart';
import 'package:mp_agency/features/product/widgets/quantity_selector.dart';
import 'package:mp_agency/features/recommendation/services/behavior_service.dart';
import 'package:mp_agency/features/store/screens/store_screen.dart';
import 'package:mp_agency/features/reservation/screens/reservation_complete_screen.dart';
import 'package:mp_agency/features/reservation/services/reservation_service.dart';
import 'package:mp_agency/features/reservation/widgets/reserve_confirm_sheet.dart';

/// 상품 상세: 사진 · 가격 · 마감까지 남은 시간 · 픽업 장소 · 수량 · 예약 버튼
class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({
    super.key,
    required this.product,
    required this.userId,
    this.distanceMeters,
  });

  final Product product;

  /// 예약하는 사용자
  final String userId;

  /// 내 위치에서 매장까지 거리 (홈에서 계산해서 전달)
  final int? distanceMeters;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _quantity = 1;

  /// 예약 처리 중 (버튼 중복 클릭 방지)
  bool _reserving = false;
  DateTime _now = DateTime.now();
  late final Timer _ticker;

  Product get _p => widget.product;

  @override
  void initState() {
    super.initState();
    BehaviorService.instance.record(
      userId: widget.userId,
      type: BehaviorType.viewProduct,
      product: _p,
    );
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

  Future<void> _reserve() async {
    final ok = await showReserveConfirmSheet(
      context,
      product: _p,
      quantity: _quantity,
    );
    if (!ok || !mounted) return;

    setState(() => _reserving = true);
    try {
      final reservation = await ReservationService.instance.reserve(
        userId: widget.userId,
        product: _p,
        quantity: _quantity,
      );
      if (!mounted) return;
      // 상세 화면을 예약 완료 화면으로 교체 (뒤로가기 시 상세로 돌아오지 않게)
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ReservationCompleteScreen(reservation: reservation),
        ),
      );
    } on StockException catch (e) {
      if (!mounted) return;
      setState(() => _reserving = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('예약하지 못했어요. ${e.message}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final available = _p.isAvailable(_now);

    return Scaffold(
      appBar: AppBar(title: const Text('오늘의 다먹음')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          _HeroImage(product: _p),
          const SizedBox(height: 18),
          _TitleSection(product: _p, distanceMeters: widget.distanceMeters),
          const SizedBox(height: 16),
          _DeadlineBox(product: _p, now: _now),
          const SizedBox(height: 16),
          PickupInfoCard(product: _p, distanceMeters: widget.distanceMeters),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      StoreScreen(storeId: _p.storeId, userId: widget.userId),
                ),
              ),
              style: TextButton.styleFrom(foregroundColor: AppColors.text),
              icon: const Icon(Icons.storefront_outlined, size: 18),
              label: Text('${_p.storeName}의 다른 음식 보기 ›'),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('수량 선택', style: AppFonts.display(size: 16)),
                  const SizedBox(height: 2),
                  Text(
                    '최대 ${_p.stockQuantity}개까지 예약할 수 있어요',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.subText,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              QuantitySelector(
                value: _quantity,
                max: _p.stockQuantity < 1 ? 1 : _p.stockQuantity,
                onChanged: (v) => setState(() => _quantity = v),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.paleGreen,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Text('🌱', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '예약하면 버려질 뻔한 음식 $_quantity개를 구하게 돼요.\n'
                    '오늘 픽업해서 오늘 다 먹어요!',
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: AppColors.deepGreen,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _ReserveBar(
        product: _p,
        quantity: _quantity,
        available: available,
        reserving: _reserving,
        onReserve: _reserve,
      ),
    );
  }
}

/// 큰 상품 그림 + 할인율·남은 수량 뱃지
class _HeroImage extends StatelessWidget {
  const _HeroImage({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final p = product;
    final placeholder = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            p.category.color,
            Color.lerp(p.category.color, Colors.white, 0.6)!,
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Text(p.displayEmoji, style: const TextStyle(fontSize: 110)),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: Stack(
          fit: StackFit.expand,
          children: [
            p.imageBytes != null
                ? Image.memory(
                    p.imageBytes!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => placeholder,
                  )
                : p.imageUrl != null
                ? Image.network(
                    p.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => placeholder,
                  )
                : placeholder,
            Positioned(
              left: 14,
              top: 14,
              child: Row(
                children: [
                  _Badge(
                    text: '-${p.discountRate}%',
                    color: AppColors.urgent,
                    textColor: Colors.white,
                  ),
                  const SizedBox(width: 6),
                  _Badge(
                    text: '${p.stockQuantity}개 남음',
                    color: Colors.white,
                    textColor: AppColors.deepGreen,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.text,
    required this.color,
    required this.textColor,
  });

  final String text;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: AppFonts.display(size: 13, color: textColor)),
    );
  }
}

/// 매장 · 상품명 · 설명 · 가격
class _TitleSection extends StatelessWidget {
  const _TitleSection({required this.product, this.distanceMeters});

  final Product product;
  final int? distanceMeters;

  @override
  Widget build(BuildContext context) {
    final p = product;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(p.category.icon, size: 15, color: AppColors.subText),
            const SizedBox(width: 4),
            Text(
              distanceMeters == null
                  ? '${p.category.label} · ${p.storeName}'
                  : '${p.category.label} · ${p.storeName} · '
                        '${formatDistance(distanceMeters!)}',
              style: const TextStyle(fontSize: 13, color: AppColors.subText),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(p.name, style: AppFonts.display(size: 26)),
        if (p.description != null) ...[
          const SizedBox(height: 6),
          Text(
            p.description!,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: AppColors.text,
            ),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${p.discountRate}%',
              style: AppFonts.display(size: 26, color: AppColors.urgent),
            ),
            const SizedBox(width: 8),
            Text(formatWon(p.discountPrice), style: AppFonts.display(size: 26)),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                formatWon(p.originalPrice),
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.subText,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 마감까지 남은 시간 박스
class _DeadlineBox extends StatelessWidget {
  const _DeadlineBox({required this.product, required this.now});

  final Product product;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final remaining = product.remaining(now);
    final ended = remaining.inSeconds <= 0;
    final urgent = remaining.inMinutes < 60;
    final color = urgent ? AppColors.urgent : AppColors.orange;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(
            urgent
                ? Icons.local_fire_department_outlined
                : Icons.schedule_rounded,
            color: color,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ended ? '판매가 끝났어요' : '마감까지 ${formatRemaining(remaining)}',
                  style: AppFonts.display(size: 17, color: color),
                ),
                const SizedBox(height: 2),
                Text(
                  '판매 종료 ${formatClock(product.saleEndAt, now: now)}',
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

/// 하단 고정: 합계 + [다먹음 예약하기]
class _ReserveBar extends StatelessWidget {
  const _ReserveBar({
    required this.product,
    required this.quantity,
    required this.available,
    required this.reserving,
    required this.onReserve,
  });

  final Product product;
  final int quantity;
  final bool available;
  final bool reserving;
  final VoidCallback onReserve;

  @override
  Widget build(BuildContext context) {
    final total = product.discountPrice * quantity;
    final saved = product.savedAmount * quantity;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  '$quantity개 · 총 ',
                  style: const TextStyle(fontSize: 13, color: AppColors.text),
                ),
                Text(formatWon(total), style: AppFonts.display(size: 16)),
                const Spacer(),
                Text(
                  '💰 ${formatWon(saved)} 절약',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.deepGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: available && !reserving ? onReserve : null,
              child: reserving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Text(available ? '다먹음 예약하기' : '판매가 끝났어요'),
            ),
            const SizedBox(height: 6),
            Text(
              '이거 버리기 아까운데… 다먹음?',
              style: AppFonts.display(size: 12, color: AppColors.subText),
            ),
          ],
        ),
      ),
    );
  }
}
