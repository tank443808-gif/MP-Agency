import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:mp_agency/features/auth/models/app_user.dart';
import 'package:mp_agency/features/auth/services/auth_service.dart';
import 'package:mp_agency/features/sync/services/data_sync.dart';
import 'package:mp_agency/features/navigation/screens/buyer_main_screen.dart';
import 'package:mp_agency/features/auth/screens/login_screen.dart';
import 'package:mp_agency/features/navigation/screens/seller_main_screen.dart';

/// 앱 시작 시 로그인 상태와 역할을 확인해 첫 화면을 결정
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Future<AppUser?> _future = _resolve();

  Future<AppUser?> _resolve() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    try {
      final profile = await AuthService.instance.fetchProfile(user.uid);
      // 프로필이 없거나 탈퇴한 계정이면 로그아웃
      if (profile == null || profile.isWithdrawn) {
        await AuthService.instance.signOut();
        return null;
      }
      return profile;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppUser?>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snap.data;
        return user == null ? const LoginScreen() : homeFor(user);
      },
    );
  }
}

/// 역할에 따라 구매자 홈 / 사업자 홈 반환
Widget homeFor(AppUser user) =>
    user.isSeller ? SellerMainScreen(user: user) : BuyerMainScreen(user: user);

/// 이전 화면을 모두 지우고 역할별 홈으로 이동
void goHome(BuildContext context, AppUser user) {
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => homeFor(user)),
    (_) => false,
  );
}

/// 로그아웃 후 로그인 화면으로 이동
Future<void> logout(BuildContext context) async {
  DataSync.instance.stop();
  await AuthService.instance.signOut();
  if (!context.mounted) return;
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const LoginScreen()),
    (_) => false,
  );
}
