import 'package:flutter/material.dart';

import 'package:mp_agency/core/theme/app_theme.dart';
import 'package:mp_agency/features/auth/models/app_user.dart';

/// 구매자 / 사업자 선택 토글
class RoleSelector extends StatelessWidget {
  const RoleSelector({super.key, required this.value, required this.onChanged});

  final UserRole value;
  final ValueChanged<UserRole> onChanged;

  static const _icons = {
    UserRole.customer: Icons.shopping_bag_outlined,
    UserRole.seller: Icons.storefront_outlined,
  };
  static const _desc = {
    UserRole.customer: '음식을 구매해요',
    UserRole.seller: '음식을 판매해요',
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final role in UserRole.values) ...[
          if (role != UserRole.values.first) const SizedBox(width: 12),
          Expanded(child: _tile(role)),
        ],
      ],
    );
  }

  Widget _tile(UserRole role) {
    final selected = role == value;
    final color = role == UserRole.seller ? AppColors.green : AppColors.orange;
    return Material(
      color: selected ? color.withValues(alpha: 0.12) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => onChanged(role),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? color : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(_icons[role], color: selected ? color : AppColors.subText),
              const SizedBox(height: 6),
              Text(
                role.label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: selected ? AppColors.text : AppColors.subText,
                ),
              ),
              Text(
                _desc[role]!,
                style: const TextStyle(fontSize: 12, color: AppColors.subText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
