import 'package:flutter/material.dart';

import 'package:mp_agency/core/theme/app_theme.dart';
import 'package:mp_agency/features/auth/screens/auth_gate.dart';
import 'package:mp_agency/features/mypage/screens/profile_screen.dart';
import 'package:mp_agency/features/product/models/product.dart';
import 'package:mp_agency/features/product/services/product_service.dart';
import 'package:mp_agency/features/store/models/store.dart';
import 'package:mp_agency/features/store/services/store_service.dart';

/// 판매자 내 가게 탭: "우리 매장 소식, 한눈에 챙겨요."
class MyStoreScreen extends StatelessWidget {
  const MyStoreScreen({super.key, required this.storeId});

  final String storeId;

  void _save(Store updated) {
    StoreService.instance.update(updated);
    ProductService.instance.syncStore(updated);
  }

  Future<void> _edit(
    BuildContext context, {
    required String title,
    required String? value,
    required Store Function(String) apply,
    int maxLines = 1,
    String? hint,
  }) async {
    final controller = TextEditingController(text: value);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cream,
        title: Text(title, style: AppFonts.display(size: 20)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: maxLines,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            style: TextButton.styleFrom(foregroundColor: AppColors.orange),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || result.isEmpty) return;
    _save(apply(result));
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$title을(를) 저장했어요.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: StreamBuilder<Store?>(
        stream: StoreService.instance.watchById(storeId),
        builder: (context, snap) {
          final s = snap.data ?? StoreService.instance.findById(storeId);
          if (s == null) return const SizedBox.shrink();

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Text(
                '우리 매장 소식,\n한눈에 챙겨요.',
                style: AppFonts.display(size: 26, height: 1.3),
              ),
              const SizedBox(height: 4),
              const Text(
                '여기서 바꾼 정보는 손님 화면에 바로 반영돼요.',
                style: TextStyle(fontSize: 13, color: AppColors.subText),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: s.category.color,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        s.displayEmoji,
                        style: const TextStyle(fontSize: 28),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.category.label,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.subText,
                            ),
                          ),
                          Text(s.name, style: AppFonts.display(size: 20)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                decoration: BoxDecoration(
                  color: s.isOpen
                      ? AppColors.paleGreen
                      : const Color(0xFFEDE7E1),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '지금 영업 상태',
                            style: TextStyle(fontSize: 12),
                          ),
                          Text(
                            s.isOpen ? '● 영업 중' : '● 영업 준비 중',
                            style: AppFonts.display(
                              size: 18,
                              color: s.isOpen
                                  ? AppColors.deepGreen
                                  : AppColors.subText,
                            ),
                          ),
                          Text(
                            s.isOpen ? '손님에게 상품이 보이고 있어요' : '손님 화면에서 상품이 숨겨져요',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.subText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: s.isOpen,
                      activeThumbColor: AppColors.deepGreen,
                      onChanged: (v) => _save(s.copyWith(isOpen: v)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text('매장 기본정보', style: AppFonts.display(size: 18)),
              const SizedBox(height: 8),
              _EditTile(
                label: '매장 이름',
                value: s.name,
                onTap: () => _edit(
                  context,
                  title: '매장 이름',
                  value: s.name,
                  apply: (v) => s.copyWith(name: v),
                ),
              ),
              _EditTile(
                label: '대표 카테고리',
                value: s.category.label,
                onTap: () async {
                  final c = await showModalBottomSheet<ProductCategory>(
                    context: context,
                    backgroundColor: AppColors.cream,
                    builder: (context) => SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final c in ProductCategory.values)
                            ListTile(
                              leading: Icon(c.icon, color: AppColors.urgent),
                              title: Text(c.label),
                              trailing: c == s.category
                                  ? const Icon(
                                      Icons.check,
                                      color: AppColors.orange,
                                    )
                                  : null,
                              onTap: () => Navigator.pop(context, c),
                            ),
                        ],
                      ),
                    ),
                  );
                  if (c != null) _save(s.copyWith(category: c));
                },
              ),
              _EditTile(
                label: '매장 소개',
                value: s.description ?? '소개를 입력해 주세요',
                onTap: () => _edit(
                  context,
                  title: '매장 소개',
                  value: s.description,
                  maxLines: 3,
                  apply: (v) => s.copyWith(description: v),
                ),
              ),
              _EditTile(
                label: '주소',
                value: s.address,
                onTap: () => _edit(
                  context,
                  title: '주소',
                  value: s.address,
                  apply: (v) => s.copyWith(address: v),
                ),
              ),
              _EditTile(
                label: '연락처',
                value: s.contactPhone ?? '연락처를 입력해 주세요',
                onTap: () => _edit(
                  context,
                  title: '연락처',
                  value: s.contactPhone,
                  hint: '031-000-0000',
                  apply: (v) => s.copyWith(contactPhone: v),
                ),
              ),
              _EditTile(
                label: '영업시간',
                value: s.hours,
                onTap: () => _edit(
                  context,
                  title: '영업시간',
                  value: s.hours,
                  hint: '09:00 ~ 21:00',
                  apply: (v) {
                    final parts = v.split('~').map((e) => e.trim()).toList();
                    return parts.length == 2
                        ? s.copyWith(openTime: parts[0], closeTime: parts[1])
                        : s;
                  },
                ),
              ),
              const SizedBox(height: 16),
              Text('픽업 안내', style: AppFonts.display(size: 18)),
              const SizedBox(height: 8),
              _EditTile(
                label: '손님에게 보여줄 안내',
                value: s.pickupGuide ?? '픽업 방법을 알려 주세요',
                onTap: () => _edit(
                  context,
                  title: '픽업 안내',
                  value: s.pickupGuide,
                  maxLines: 3,
                  apply: (v) => s.copyWith(pickupGuide: v),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.paleGreen,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  '🌱 가게 문 닫기 전, 남은 음식을 등록하면\n폐기는 줄고 매출은 늘어요.',
                  style: TextStyle(fontSize: 13, height: 1.5),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.text,
                  minimumSize: const Size.fromHeight(46),
                  side: const BorderSide(color: AppColors.border),
                ),
                icon: const Icon(Icons.person_outline_rounded),
                label: const Text('계정·알림 설정'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => logout(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.subText,
                  minimumSize: const Size.fromHeight(46),
                  side: const BorderSide(color: AppColors.border),
                ),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('로그아웃'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EditTile extends StatelessWidget {
  const _EditTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        onTap: onTap,
        title: Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.subText),
        ),
        subtitle: Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.text,
            fontWeight: FontWeight.w700,
          ),
        ),
        trailing: const Text(
          '수정',
          style: TextStyle(
            color: AppColors.orange,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
