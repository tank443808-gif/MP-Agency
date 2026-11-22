import 'package:flutter/material.dart';

import 'package:mp_agency/core/theme/app_theme.dart';

/// 둥근 선택 칩 (필터·카테고리 선택용)
///
/// Material 칩은 웹에서 글꼴을 늦게 받으면 글자가 잘려 보이는 경우가 있어
/// 직접 만든 칩을 씀.
class PillChip extends StatelessWidget {
  const PillChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.filled = true,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  /// 선택 시 오렌지로 꽉 채울지(true), 연한 살구색으로 표시할지(false)
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? (filled ? AppColors.orange : AppColors.peach)
        : Colors.white;
    final fg = selected
        ? (filled ? Colors.white : AppColors.urgent)
        : AppColors.text;

    return Material(
      color: bg,
      shape: StadiumBorder(
        side: BorderSide(color: selected ? AppColors.orange : AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: selected ? fg : AppColors.urgent),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                softWrap: false,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
