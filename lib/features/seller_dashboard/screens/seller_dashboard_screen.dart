import 'package:flutter/material.dart';

import 'package:mp_agency/core/theme/app_theme.dart';
import 'package:mp_agency/core/utils/formatters.dart';
import 'package:mp_agency/core/widgets/app_logo.dart';
import 'package:mp_agency/core/widgets/pill_chip.dart';
import 'package:mp_agency/features/auth/models/app_user.dart';
import 'package:mp_agency/features/notification/widgets/notification_bell.dart';
import 'package:mp_agency/features/product/models/product.dart';
import 'package:mp_agency/features/product/screens/product_form_screen.dart';
import 'package:mp_agency/features/product/services/product_service.dart';
import 'package:mp_agency/features/product/widgets/product_card.dart';
import 'package:mp_agency/features/reservation/models/reservation.dart';
import 'package:mp_agency/features/reservation/services/reservation_service.dart';
import 'package:mp_agency/features/seller_dashboard/models/seller_stats.dart';
import 'package:mp_agency/features/store/models/store.dart';

/// 판매자 대시보드 (기능명세 DASH-001 판매 현황, DASH-005 폐기 감소 통계)
class SellerDashboardScreen extends StatelessWidget {
  const SellerDashboardScreen({
    super.key,
    required this.user,
    required this.store,
    required this.onGoTab,
  });

  final AppUser user;
  final Store store;

  /// 다른 탭으로 이동 (1: 상품 관리, 2: 예약 관리)
  final ValueChanged<int> onGoTab;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: StreamBuilder<List<Product>>(
        stream: ProductService.instance.watchByStore(store.id),
        builder: (context, pSnap) {
          return StreamBuilder<List<Reservation>>(
            stream: ReservationService.instance.watchByStore(store.id),
            builder: (context, rSnap) {
              final now = DateTime.now();
              final products = pSnap.data ?? const <Product>[];
              final reservations = rSnap.data ?? const <Reservation>[];
              final onSale = products.where((p) => p.isAvailable(now)).toList();
              final pending =
                  reservations
                      .where(
                        (r) =>
                            r.displayStatus(now) == ReservationStatus.reserved,
                      )
                      .toList()
                    ..sort(
                      (a, b) => a.pickupDeadline.compareTo(b.pickupDeadline),
                    );

              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  Row(
                    children: [
                      const AppLogo(size: 24),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.lightGreen,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '사장님',
                          style: AppFonts.display(
                            size: 11,
                            color: AppColors.deepGreen,
                          ),
                        ),
                      ),
                      const Spacer(),
                      NotificationBell(userId: user.uid),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${store.name} 사장님,\n오늘도 맛있는 마무리!',
                    style: AppFonts.display(size: 24, height: 1.3),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    store.isOpen ? '● 영업 중 · ${store.hours}' : '● 영업 준비 중',
                    style: TextStyle(
                      fontSize: 13,
                      color: store.isOpen
                          ? AppColors.deepGreen
                          : AppColors.subText,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _StatsCard(
                    products: products,
                    reservations: reservations,
                    now: now,
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ProductFormScreen(store: store),
                      ),
                    ),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('오늘의 상품 등록'),
                  ),
                  const SizedBox(height: 22),
                  _SectionHeader(
                    title: '픽업 대기',
                    count: pending.length,
                    onMore: () => onGoTab(2),
                  ),
                  if (pending.isEmpty)
                    const _Empty(text: '지금 기다리는 예약이 없어요.')
                  else
                    for (final r in pending.take(3))
                      _MiniRow(
                        product: r.product,
                        title: '${r.product.name} · ${r.quantity}개',
                        subtitle:
                            '${formatRemaining(r.pickupDeadline.difference(now)).replaceAll(' 남음', '')} 안에 픽업',
                        trailing: formatWon(r.totalPrice),
                      ),
                  const SizedBox(height: 16),
                  _SectionHeader(
                    title: '판매 중인 상품',
                    count: onSale.length,
                    onMore: () => onGoTab(1),
                  ),
                  if (onSale.isEmpty)
                    const _Empty(text: '판매 중인 상품이 없어요. 남은 음식을 등록해 보세요!')
                  else
                    for (final p in onSale.take(3))
                      _MiniRow(
                        product: p,
                        title: p.name,
                        subtitle:
                            '남은 ${p.stockQuantity}개 · ${formatRemaining(p.remaining(now))}',
                        trailing:
                            '${p.discountRate}% ${formatWon(p.discountPrice)}',
                      ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// 연두 카드: 회수한 매출 · 등록/판매/폐기 · 폐기 감소율
class _StatsCard extends StatefulWidget {
  const _StatsCard({
    required this.products,
    required this.reservations,
    required this.now,
  });

  final List<Product> products;
  final List<Reservation> reservations;
  final DateTime now;

  @override
  State<_StatsCard> createState() => _StatsCardState();
}

class _StatsCardState extends State<_StatsCard> {
  StatsPeriod _period = StatsPeriod.all;

  @override
  Widget build(BuildContext context) {
    final stats = SellerStats.from(
      products: widget.products,
      reservations: widget.reservations,
      now: widget.now,
      period: _period,
    );
    final rate = stats.wasteReductionRate;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.paleGreen,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.lightGreen),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final p in StatsPeriod.values)
                PillChip(
                  label: p.label,
                  selected: p == _period,
                  onTap: () => setState(() => _period = p),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '${_period == StatsPeriod.all ? '' : '${_period.label} '}다먹음으로 회수한 매출',
            style: AppFonts.display(size: 14, color: AppColors.deepGreen),
          ),
          const SizedBox(height: 2),
          Text(
            formatWon(stats.recoveredRevenue),
            style: AppFonts.display(size: 34),
          ),
          Text(
            '오늘 ${formatWon(stats.todayRevenue)}',
            style: const TextStyle(fontSize: 12, color: AppColors.subText),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _Num(label: '등록', value: '${stats.registeredCount}개'),
              _Num(label: '판매', value: '${stats.soldCount}개'),
              _Num(
                label: '폐기',
                value: '${stats.wastedCount}개',
                color: AppColors.urgent,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Text('🌱 폐기 감소율', style: TextStyle(fontSize: 13)),
              const Spacer(),
              Text(
                rate == null ? '-' : '${(rate * 100).round()}%',
                style: AppFonts.display(size: 18, color: AppColors.deepGreen),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: rate ?? 0,
              minHeight: 10,
              backgroundColor: Colors.white,
              color: AppColors.green,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '판매 ÷ (판매 + 폐기). 남은 재고와 노쇼는 폐기로 계산해요.',
            style: TextStyle(fontSize: 11, color: AppColors.subText),
          ),
        ],
      ),
    );
  }
}

class _Num extends StatelessWidget {
  const _Num({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.subText),
          ),
          Text(
            value,
            style: AppFonts.display(size: 20, color: color ?? AppColors.text),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.count,
    required this.onMore,
  });

  final String title;
  final int count;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: AppFonts.display(size: 18)),
        const SizedBox(width: 6),
        Text(
          '$count',
          style: AppFonts.display(size: 18, color: AppColors.orange),
        ),
        const Spacer(),
        TextButton(
          onPressed: onMore,
          style: TextButton.styleFrom(foregroundColor: AppColors.subText),
          child: const Text('관리하기 ›'),
        ),
      ],
    );
  }
}

class _MiniRow extends StatelessWidget {
  const _MiniRow({
    required this.product,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final Product product;
  final String title;
  final String subtitle;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          ProductThumbnail(product: product, size: 44),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.display(size: 14),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: AppColors.urgent),
                ),
              ],
            ),
          ),
          Text(trailing, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(text, style: const TextStyle(color: AppColors.subText)),
    );
  }
}
