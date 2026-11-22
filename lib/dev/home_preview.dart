// 개발용: 로그인 없이 구매자 홈 화면만 바로 띄워 보는 진입점
// 실행: flutter run -d chrome -t lib/dev/home_preview.dart
import 'package:flutter/material.dart';

import 'package:mp_agency/core/theme/app_theme.dart';
import 'package:mp_agency/features/auth/models/app_user.dart';
import 'package:mp_agency/features/navigation/screens/buyer_main_screen.dart';

void main() {
  runApp(
    MaterialApp(
      title: '다먹음 (홈 미리보기)',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const BuyerMainScreen(
        user: AppUser(
          uid: 'preview',
          email: 'preview@example.com',
          nickname: '미리보기',
          role: UserRole.customer,
        ),
      ),
    ),
  );
}
