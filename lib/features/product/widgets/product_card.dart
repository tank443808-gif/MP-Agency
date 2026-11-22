import 'package:flutter/material.dart';

import 'package:mp_agency/core/theme/app_theme.dart';
import 'package:mp_agency/core/utils/formatters.dart';
import 'package:mp_agency/features/product/models/product.dart';

/// 상품 카드: 그림(+할인율 뱃지) · 남은 시간 칩 · 상품명 · 매장/거리 · 가격
/// (홈, 내 주변 등 상품 목록에서 공용으로 사용)
class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.now,
    this.distanceMeters,
    this.onTap,
  });

  final Product product;

  /// 남은 시간 계산 기준 시각 (목록 전체가 같은 시각을 쓰도록 밖에서 전달)
  final DateTime now;

  /// 내 위치에서 매장까지 거리 (위치를 모르면 null)
  final int? distanceMeters;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = product;
    final store = distanceMeters == null
        ? p.storeName
        : '${p.storeName} · ${formatDistance(distanceMeters!)}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        shadowColor: AppColors.shadow,
        elevation: 3,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ProductThumbnail(product: p, size: 92, showBadge: true),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TimeChip(remaining: p.remaining(now)),
                      const SizedBox(height: 6),
                      Text(
                        p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.display(size: 17),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.storefront_rounded,
                            size: 13,
                            color: AppColors.subText,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              store,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.subText,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            formatWon(p.discountPrice),
                            style: AppFonts.display(size: 19),
                          ),
                          const SizedBox(width: 6),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              formatWon(p.originalPrice),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.subText,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${p.stockQuantity}개 남음',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.deepGreen,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "⏰ 48분 남음" 칩. 1시간 이내면 빨간색으로 강조.
class _TimeChip extends StatelessWidget {
  const _TimeChip({required this.remaining});

  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    final urgent = remaining.inMinutes < 60;
    final color = urgent ? AppColors.urgent : AppColors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            urgent ? Icons.local_fire_department_rounded : Icons.schedule,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 3),
          Text(
            formatRemaining(remaining),
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

/// 상품 그림. 올린 사진 → 사진 주소 → 파스텔 배경 + 음식 그림 순서로 보여줌.
class ProductThumbnail extends StatelessWidget {
  const ProductThumbnail({
    super.key,
    required this.product,
    this.size = 92,
    this.showBadge = false,
  });

  final Product product;
  final double size;

  /// 왼쪽 위에 할인율 뱃지 표시
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            product.category.color,
            Color.lerp(product.category.color, Colors.white, 0.55)!,
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Text(product.displayEmoji, style: TextStyle(fontSize: size * 0.5)),
    );

    final image = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: product.imageBytes != null
          ? Image.memory(
              product.imageBytes!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => placeholder,
            )
          : product.imageUrl != null
          ? Image.network(
              product.imageUrl!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => placeholder,
            )
          : placeholder,
    );

    if (!showBadge || product.discountRate <= 0) return image;

    return Stack(
      children: [
        image,
        Positioned(
          left: 6,
          top: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.urgent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '-${product.discountRate}%',
              style: AppFonts.display(size: 12, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
