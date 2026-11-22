import 'package:flutter/material.dart';

import 'package:mp_agency/core/theme/app_theme.dart';

/// 목록 아래 안내 박스
class HomeTipBox extends StatelessWidget {
  const HomeTipBox({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.paleGreen,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.lightGreen),
      ),
      child: Row(
        children: [
          const Text('🌱', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '제때 받아가면 다먹음 지수 UP!',
                  style: AppFonts.display(size: 15, color: AppColors.deepGreen),
                ),
                const SizedBox(height: 2),
                const Text(
                  '예약한 음식은 픽업 시간 안에 받아가 주세요.',
                  style: TextStyle(fontSize: 12, color: AppColors.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
