import 'package:flutter/material.dart';

import 'package:mp_agency/core/theme/app_theme.dart';
import 'package:mp_agency/core/utils/formatters.dart';
import 'package:mp_agency/features/favorite/services/favorite_service.dart';
import 'package:mp_agency/features/favorite/widgets/favorite_button.dart';
import 'package:mp_agency/features/location/services/location_service.dart';
import 'package:mp_agency/features/product/services/product_service.dart';
import 'package:mp_agency/features/store/screens/store_screen.dart';
import 'package:mp_agency/features/store/services/store_service.dart';

/// 나의 찜 목록: "이 중에서 먹자!"
class FavoriteListScreen extends StatelessWidget {
  const FavoriteListScreen({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('나의 찜 목록')),
      body: StreamBuilder<Set<String>>(
        stream: FavoriteService.instance.watch(userId),
        builder: (context, snap) {
          final ids = snap.data ?? const <String>{};
          final stores = StoreService.instance.all
              .where((s) => ids.contains(s.id))
              .toList();
          final onSale = ProductService.instance.onSale();

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              Text(
                '찜한 매장',
                style: AppFonts.display(size: 13, color: AppColors.urgent),
              ),
              Text('이 중에서 먹자!', style: AppFonts.display(size: 26)),
              const SizedBox(height: 16),
              if (stores.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.paleGreen,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Text(
                    '아직 찜한 매장이 없어요.\n매장 화면에서 ♡를 눌러 단골 매장을 모아 보세요!',
                    style: TextStyle(height: 1.5),
                  ),
                )
              else
                for (final s in stores)
                  Builder(
                    builder: (context) {
                      final items = onSale
                          .where((p) => p.storeId == s.id)
                          .toList();
                      // 내 위치에서 매장까지 거리
                      final loc = LocationService.instance.last;
                      final distance = loc == null
                          ? null
                          : LocationService.instance.distanceMeters(
                              loc.latitude,
                              loc.longitude,
                              s.latitude,
                              s.longitude,
                            );
                      final minPrice = items.isEmpty
                          ? null
                          : items
                                .map((p) => p.discountPrice)
                                .reduce((a, b) => a < b ? a : b);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    StoreScreen(storeId: s.id, userId: userId),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 64,
                                    height: 64,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: s.category.color,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      s.displayEmoji,
                                      style: const TextStyle(fontSize: 32),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          [
                                            s.category.label,
                                            s.isOpen ? '영업 중' : '영업 준비 중',
                                            if (distance != null)
                                              formatDistance(distance),
                                          ].join(' · '),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: s.isOpen
                                                ? AppColors.deepGreen
                                                : AppColors.subText,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        Text(
                                          s.name,
                                          style: AppFonts.display(size: 17),
                                        ),
                                        Text(
                                          items.isEmpty
                                              ? '지금은 남은 음식이 없어요'
                                              : '지금 ${items.length}개 판매 중 · '
                                                    '${formatWon(minPrice!)}부터',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.subText,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  FavoriteButton(
                                    userId: userId,
                                    storeId: s.id,
                                    background: null,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
            ],
          );
        },
      ),
    );
  }
}
