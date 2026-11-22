import 'package:flutter/material.dart';

import 'package:mp_agency/core/theme/app_theme.dart';

/// 메인 배너: "버려지기 전에, 다 먹음." + 지금 구출 가능한 음식 수
class HomeBanner extends StatelessWidget {
  const HomeBanner({super.key, required this.rescuableCount, this.onTap});

  /// 지금 구출 가능한 상품 수
  final int rescuableCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(24);
    return Material(
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE4F3C4), Color(0xFFC9E79A)],
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              // 오른쪽 아래 음식 그림 (살짝 겹치게 배치)
              const Positioned(right: -6, bottom: -8, child: _FoodCluster()),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '🌱 지금 $rescuableCount개 구출 대기 중',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.deepGreen,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '버려지기 전에,\n다 먹음.',
                      style: AppFonts.display(size: 30, height: 1.2),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '이거 버리기 아까운데… 다먹음?',
                      style: TextStyle(fontSize: 13, color: AppColors.text),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.deepGreen,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '마감 임박 음식 보기 →',
                        style: AppFonts.display(size: 13, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 크림색 접시 위에 음식 그림 3개
class _FoodCluster extends StatelessWidget {
  const _FoodCluster();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      height: 130,
      child: Stack(
        children: [
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const Positioned(
            right: 30,
            bottom: 34,
            child: Text('🥐', style: TextStyle(fontSize: 52)),
          ),
          const Positioned(
            right: 82,
            bottom: 18,
            child: Text('🥪', style: TextStyle(fontSize: 34)),
          ),
          const Positioned(
            right: 14,
            bottom: 12,
            child: Text('🍙', style: TextStyle(fontSize: 30)),
          ),
        ],
      ),
    );
  }
}
