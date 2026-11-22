import 'package:flutter/material.dart';

import 'package:mp_agency/core/theme/app_theme.dart';
import 'package:mp_agency/features/location/models/user_location.dart';
import 'package:mp_agency/features/location/services/location_service.dart';

/// 위치 고르기 시트 (기능명세 SRCH-005 "주변 또는 선택 지역")
///
/// 고르면 [LocationService.location]이 바뀌어 홈·내 주변이 함께 바뀜.
/// "현재 위치"를 고르면 true를 돌려줌 (GPS 다시 찾기).
Future<bool> showLocationPicker(BuildContext context) async {
  final current = LocationService.instance.last;
  final result = await showModalBottomSheet<Object>(
    context: context,
    backgroundColor: AppColors.cream,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('어디서 찾아볼까요?', style: AppFonts.display(size: 22)),
            const SizedBox(height: 4),
            const Text(
              '고른 위치를 기준으로 거리와 가까운 매장을 보여드려요.',
              style: TextStyle(fontSize: 13, color: AppColors.subText),
            ),
            const SizedBox(height: 12),
            _Option(
              icon: Icons.my_location_rounded,
              iconColor: const Color(0xFF3D8BFF),
              title: '현재 위치 (GPS)',
              subtitle: '내 위치를 다시 찾아요',
              selected: current?.status == LocationStatus.current,
              onTap: () => Navigator.pop(context, true),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 12, 4, 6),
              child: Text(
                '지역 선택',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.subText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (final area in LocationService.presetAreas)
              _Option(
                icon: Icons.place_outlined,
                iconColor: AppColors.urgent,
                title: area.label,
                selected:
                    current?.status == LocationStatus.selected &&
                    current?.label == area.label,
                onTap: () => Navigator.pop(context, area),
              ),
          ],
        ),
      ),
    ),
  );
  if (result is UserLocation) {
    LocationService.instance.select(result);
    return false;
  }
  return result == true;
}

class _Option extends StatelessWidget {
  const _Option({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected ? AppColors.peach : Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
          onTap: onTap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: selected ? AppColors.orange : AppColors.border,
            ),
          ),
          leading: Icon(icon, color: iconColor),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: subtitle == null ? null : Text(subtitle!),
          trailing: selected
              ? const Icon(Icons.check_rounded, color: AppColors.orange)
              : null,
        ),
      ),
    );
  }
}
