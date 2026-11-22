import 'package:flutter/material.dart';

import 'package:mp_agency/core/theme/app_theme.dart';

/// 다먹음 로고: 오렌지 그릇 + 연두 새싹 마크 + 「다먹음」 글자
///
/// [size]는 글자 크기 기준. 마크는 글자에 맞춰 자동으로 커짐.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 26, this.showMark = true});

  final double size;
  final bool showMark;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showMark) ...[
          LogoMark(size: size * 1.25),
          SizedBox(width: size * 0.3),
        ],
        Text(
          '다먹음',
          style: AppFonts.display(size: size, color: AppColors.orange),
        ),
      ],
    );
  }
}

/// 로고 마크만 (그릇 + 새싹)
class LogoMark extends StatelessWidget {
  const LogoMark({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.orange,
              borderRadius: BorderRadius.circular(size * 0.32),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.rice_bowl_rounded,
              color: Colors.white,
              size: size * 0.6,
            ),
          ),
          Positioned(
            right: -size * 0.12,
            top: -size * 0.14,
            child: Container(
              padding: EdgeInsets.all(size * 0.04),
              decoration: const BoxDecoration(
                color: AppColors.cream,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.eco_rounded,
                color: AppColors.green,
                size: size * 0.38,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
