import 'package:flutter/material.dart';

import 'package:mp_agency/core/theme/app_theme.dart';
import 'package:mp_agency/core/utils/formatters.dart';
import 'package:mp_agency/features/product/widgets/product_card.dart';
import 'package:mp_agency/features/recommendation/services/recommendation_service.dart';

/// 홈 "○○님을 위한 추천" 가로 목록 (기능명세 AI-002 개인화 추천, AI-004 추천 이유)
class RecommendationSection extends StatelessWidget {
  const RecommendationSection({
    super.key,
    required this.nickname,
    required this.items,
    required this.hasHistory,
    required this.onTap,
  });

  final String nickname;
  final List<Recommendation> items;

  /// 행동 기록이 있는지 (없으면 "할인·마감·거리 기준" 안내)
  final bool hasHistory;
  final ValueChanged<Recommendation> onTap;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.auto_awesome_rounded,
              color: AppColors.orange,
              size: 20,
            ),
            const SizedBox(width: 6),
            Text('$nickname님을 위한 추천', style: AppFonts.display(size: 20)),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          hasHistory
              ? '자주 보는 음식·가격대·마감 시간·거리를 분석했어요'
              : '할인율·마감 시간·거리로 골랐어요. 둘러볼수록 더 잘 맞춰요!',
          style: const TextStyle(fontSize: 12, color: AppColors.subText),
        ),
        const SizedBox(height: 10),
        SizedBox(
          // 그림 130 + 이유 칩 + 상품명 + 가격 + 여백. 대체 글꼴은 줄 높이가 커서 여유 있게.
          height: 244,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) =>
                _RecommendCard(item: items[i], onTap: () => onTap(items[i])),
          ),
        ),
      ],
    );
  }
}

class _RecommendCard extends StatelessWidget {
  const _RecommendCard({required this.item, required this.onTap});

  final Recommendation item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = item.product;
    return SizedBox(
      width: 150,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        elevation: 2,
        shadowColor: AppColors.shadow,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProductThumbnail(product: p, size: 130, showBadge: true),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.paleGreen,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    item.reason,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.deepGreen,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  p.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.display(size: 14),
                ),
                Text(
                  formatWon(p.discountPrice),
                  style: AppFonts.display(size: 14, color: AppColors.urgent),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
