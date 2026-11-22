import 'package:flutter/material.dart';

import 'package:mp_agency/core/theme/app_theme.dart';
import 'package:mp_agency/features/auth/models/app_user.dart';
import 'package:mp_agency/features/auth/screens/login_screen.dart';
import 'package:mp_agency/features/mypage/services/profile_service.dart';
import 'package:mp_agency/features/notification/models/app_notification.dart';
import 'package:mp_agency/features/notification/services/notification_service.dart';

/// 프로필·설정 (기능명세 MY-001 사용자 정보 및 설정 관리)
/// 닉네임 수정 · 알림 설정 · 회원 탈퇴
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _editNickname(BuildContext context, AppUser user) async {
    final controller = TextEditingController(text: user.nickname);
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cream,
        title: Text('닉네임 바꾸기', style: AppFonts.display(size: 20)),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            maxLength: 12,
            validator: ProfileService.validateNickname,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.orange),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || result == user.nickname) return;
    try {
      await ProfileService.instance.updateNickname(result);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$result님, 닉네임을 바꿨어요.')));
      }
    } on ProfileException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _withdraw(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cream,
        title: Text('정말 탈퇴할까요?', style: AppFonts.display(size: 20)),
        content: const Text(
          '탈퇴하면 이 계정으로 다시 로그인할 수 없어요.\n'
          '지금까지의 다먹음 기록도 더는 볼 수 없어요.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('더 써볼게요'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.urgent),
            child: const Text('탈퇴하기'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ProfileService.instance.withdraw();
      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } on ProfileException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppUser?>(
      valueListenable: ProfileService.instance.current,
      builder: (context, user, _) {
        if (user == null) {
          return const Scaffold(body: Center(child: Text('로그인 정보가 없어요.')));
        }
        final groups = user.isSeller
            ? const [NotificationGroup.store]
            : const [
                NotificationGroup.reservation,
                NotificationGroup.recommendation,
              ];

        return Scaffold(
          appBar: AppBar(title: const Text('프로필·설정')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              const _Section('내 정보'),
              _Tile(
                label: '닉네임',
                value: user.nickname,
                action: '수정',
                onTap: () => _editNickname(context, user),
              ),
              _Tile(label: '이메일', value: user.email),
              _Tile(
                label: '회원 유형',
                value: user.isSeller
                    ? '${user.role.label} · ${user.storeName ?? ''}'
                    : user.role.label,
              ),
              const SizedBox(height: 18),
              const _Section('알림 설정'),
              StreamBuilder<Object?>(
                // 설정이 바뀌면 다시 그리기
                stream: NotificationService.instance.watch(user.uid),
                builder: (context, _) => Column(
                  children: [
                    for (final g in groups)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: SwitchListTile(
                          value: NotificationService.instance.isOn(user.uid, g),
                          activeThumbColor: AppColors.orange,
                          onChanged: (v) => NotificationService.instance.setOn(
                            user.uid,
                            g,
                            v,
                          ),
                          title: Text(
                            g.label,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            g.description,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: TextButton(
                  onPressed: () => _withdraw(context),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.subText,
                  ),
                  child: const Text('회원 탈퇴'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: AppFonts.display(size: 18)),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.label,
    required this.value,
    this.action,
    this.onTap,
  });

  final String label;
  final String value;
  final String? action;
  final VoidCallback? onTap;

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
            fontSize: 15,
            color: AppColors.text,
            fontWeight: FontWeight.w700,
          ),
        ),
        trailing: action == null
            ? null
            : Text(
                action!,
                style: const TextStyle(
                  color: AppColors.orange,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}
