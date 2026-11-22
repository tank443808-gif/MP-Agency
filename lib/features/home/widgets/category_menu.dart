import 'package:flutter/material.dart';

import 'package:mp_agency/core/theme/app_theme.dart';
import 'package:mp_agency/features/product/models/product.dart';

/// 카테고리 4개 (베이커리 · 간편식 · 카페 · 식사)
/// 연한 살구색 원 + 오렌지 선 아이콘. 누르면 선택, 한 번 더 누르면 해제.
class CategoryMenu extends StatelessWidget {
  const CategoryMenu({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final ProductCategory? selected;
  final ValueChanged<ProductCategory?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final c in ProductCategory.values)
          Expanded(
            child: _CategoryItem(
              category: c,
              selected: c == selected,
              onTap: () => onChanged(c == selected ? null : c),
            ),
          ),
      ],
    );
  }
}

class _CategoryItem extends StatelessWidget {
  const _CategoryItem({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final ProductCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? AppColors.orange : const Color(0xFFFFEDE2),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: AppColors.orange.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              category.icon,
              size: 28,
              color: selected ? Colors.white : AppColors.urgent,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            category.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: selected ? AppColors.orange : AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}
