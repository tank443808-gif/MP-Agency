import 'package:flutter/material.dart';

import 'package:mp_agency/core/theme/app_theme.dart';
import 'package:mp_agency/core/widgets/app_logo.dart';

/// 로그인·회원가입 상단: 큰 로고 + 슬로건
class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: AppColors.orange.withValues(alpha: 0.28),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const LogoMark(size: 84),
        ),
        const SizedBox(height: 18),
        const AppLogo(size: 38, showMark: false),
        const SizedBox(height: 6),
        Text(
          '버려지기 전에, 다 먹음.',
          style: AppFonts.display(size: 16, color: AppColors.subText),
        ),
      ],
    );
  }
}
