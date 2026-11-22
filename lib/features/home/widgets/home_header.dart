import 'package:flutter/material.dart';

import 'package:mp_agency/core/theme/app_theme.dart';
import 'package:mp_agency/core/widgets/app_logo.dart';

/// 홈 상단: 다먹음 로고 + 알림 버튼, 그 아래 현재 위치
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.locationName,
    this.locationHint = '지금 픽업 가능한 음식을 보여드려요',
    this.isLocating = false,
    this.hintIsWarning = false,
    this.trailing,
    this.onLocationTap,
  });

  final String locationName;

  /// 위치 옆 작은 안내 문구
  final String locationHint;

  /// GPS 위치를 찾는 중인지
  final bool isLocating;

  /// 안내 문구를 경고색으로 표시 (권한 거부 등)
  final bool hintIsWarning;

  /// 오른쪽 위 버튼 (알림 종)
  final Widget? trailing;
  final VoidCallback? onLocationTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [const AppLogo(size: 26), const Spacer(), ?trailing]),
        InkWell(
          onTap: onLocationTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                isLocating
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.orange,
                        ),
                      )
                    : const Icon(
                        Icons.place,
                        size: 16,
                        color: AppColors.orange,
                      ),
                const SizedBox(width: 4),
                Text(
                  isLocating ? '위치 찾는 중…' : locationName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: AppColors.subText,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    locationHint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: hintIsWarning
                          ? AppColors.urgent
                          : AppColors.subText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
