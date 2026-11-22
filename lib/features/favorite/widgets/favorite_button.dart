import 'package:flutter/material.dart';

import 'package:mp_agency/core/theme/app_theme.dart';
import 'package:mp_agency/features/favorite/services/favorite_service.dart';

/// 매장 찜 하트 버튼
class FavoriteButton extends StatelessWidget {
  const FavoriteButton({
    super.key,
    required this.userId,
    required this.storeId,
    this.size = 24,
    this.background = Colors.white,
  });

  final String userId;
  final String storeId;
  final double size;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Set<String>>(
      stream: FavoriteService.instance.watch(userId),
      builder: (context, snap) {
        final on = snap.data?.contains(storeId) ?? false;
        return IconButton(
          tooltip: on ? '찜 해제' : '찜하기',
          style: IconButton.styleFrom(backgroundColor: background),
          onPressed: () {
            final now = FavoriteService.instance.toggle(userId, storeId);
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(now ? '찜했어요! 나의 찜 목록에서 볼 수 있어요.' : '찜을 해제했어요.'),
                  duration: const Duration(seconds: 2),
                ),
              );
          },
          icon: Icon(
            on ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: on ? AppColors.urgent : AppColors.subText,
            size: size,
          ),
        );
      },
    );
  }
}
