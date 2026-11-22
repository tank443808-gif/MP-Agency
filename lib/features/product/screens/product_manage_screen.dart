import 'dart:async';

import 'package:flutter/material.dart';

import 'package:mp_agency/core/theme/app_theme.dart';
import 'package:mp_agency/core/utils/formatters.dart';
import 'package:mp_agency/features/product/models/product.dart';
import 'package:mp_agency/features/product/screens/product_form_screen.dart';
import 'package:mp_agency/features/product/services/product_service.dart';
import 'package:mp_agency/features/product/widgets/product_card.dart';
import 'package:mp_agency/features/store/models/store.dart';

/// 판매자 상품 관리 탭 (기능명세 SELL-004): "재고 관리를 한눈에!"
class ProductManageScreen extends StatefulWidget {
  const ProductManageScreen({super.key, required this.store});

  final Store store;

  @override
  State<ProductManageScreen> createState() => _ProductManageScreenState();
}

class _ProductManageScreenState extends State<ProductManageScreen> {
  late final Stream<List<Product>> _stream = ProductService.instance
      .watchByStore(widget.store.id);
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

  void _openForm({Product? edit, Product? copy}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductFormScreen(
          store: widget.store,
          product: edit,
          copyFrom: copy,
        ),
      ),
    );
  }

  Future<void> _endSale(Product p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cream,
        title: Text('판매를 종료할까요?', style: AppFonts.display(size: 20)),
        content: Text(
          '${p.name}이(가) 손님 화면에서 사라져요.\n'
          '남은 ${p.stockQuantity}개는 폐기로 집계돼요.',
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('계속 판매'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.urgent),
            child: const Text('판매 종료'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    ProductService.instance.endSale(p.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('${p.name} 판매를 종료했어요.')));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: StreamBuilder<List<Product>>(
        stream: _stream,
        builder: (context, snap) {
          final all = snap.data ?? const <Product>[];
          final onSale = all.where((p) => p.isAvailable(_now)).toList();
          final finished = all.where((p) => !p.isAvailable(_now)).toList();
          final stockLeft = onSale.fold<int>(0, (s, p) => s + p.stockQuantity);

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            children: [
              Text(
                '오늘의 재고',
                style: AppFonts.display(size: 13, color: AppColors.urgent),
              ),
              Text('재고 관리를 한눈에!', style: AppFonts.display(size: 26)),
              const SizedBox(height: 4),
              Text(
                '판매 중 ${onSale.length}개 상품 · 남은 재고 $stockLeft개',
                style: const TextStyle(fontSize: 13, color: AppColors.subText),
              ),
              const SizedBox(height: 16),
              if (all.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.paleGreen,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Text(
                    '아직 등록한 상품이 없어요.\n오른쪽 아래 [+ 상품 등록]으로 남은 음식을 올려 보세요!',
                    style: TextStyle(height: 1.5),
                  ),
                ),
              for (final p in onSale)
                _ManageTile(
                  product: p,
                  now: _now,
                  onTap: () => _openForm(edit: p),
                  onEnd: () => _endSale(p),
                ),
              if (finished.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('판매 끝난 상품', style: AppFonts.display(size: 18)),
                const SizedBox(height: 8),
                for (final p in finished)
                  _ManageTile(
                    product: p,
                    now: _now,
                    onTap: () => _openForm(copy: p),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ManageTile extends StatelessWidget {
  const _ManageTile({
    required this.product,
    required this.now,
    required this.onTap,
    this.onEnd,
  });

  final Product product;
  final DateTime now;
  final VoidCallback onTap;

  /// 판매 종료 (판매 중인 상품만)
  final VoidCallback? onEnd;

  @override
  Widget build(BuildContext context) {
    final p = product;
    final status = p.displayStatus(now);
    final active = status == ProductStatus.onSale;
    final sold = p.totalStock - p.stockQuantity;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Opacity(
            opacity: active ? 1 : 0.7,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ProductThumbnail(product: p, size: 72),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          active
                              ? '${formatRemaining(p.remaining(now))} · '
                                    '${formatClock(p.saleEndAt, now: now)} 종료'
                              : status.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: active
                                ? AppColors.urgent
                                : AppColors.subText,
                          ),
                        ),
                        Text(
                          p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.display(size: 16),
                        ),
                        Text(
                          '${p.discountRate}% ${formatWon(p.discountPrice)} · '
                          '판매 $sold / ${p.totalStock}개',
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: p.totalStock == 0 ? 0 : sold / p.totalStock,
                            minHeight: 5,
                            backgroundColor: AppColors.border,
                            color: AppColors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (onEnd != null)
                    PopupMenuButton<String>(
                      tooltip: '더보기',
                      onSelected: (v) => v == 'end' ? onEnd!() : onTap(),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('수정하기')),
                        PopupMenuItem(value: 'end', child: Text('판매 종료')),
                      ],
                    )
                  else
                    const Tooltip(
                      message: '같은 상품 다시 등록',
                      child: Icon(
                        Icons.replay_rounded,
                        color: AppColors.subText,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
