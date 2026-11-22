// 개발용: 로그인 없이 판매자 화면만 바로 띄워 보는 진입점
// 실행: flutter run -d chrome -t lib/dev/seller_preview.dart
// "신구 베이커리" 예시 매장을 맡은 사장님으로 들어가요.
import 'package:flutter/material.dart';

import 'package:mp_agency/core/theme/app_theme.dart';
import 'package:mp_agency/features/auth/models/app_user.dart';
import 'package:mp_agency/features/navigation/screens/seller_main_screen.dart';

void main() {
  runApp(
    MaterialApp(
      title: '다먹음 (사장님 미리보기)',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const SellerMainScreen(
        user: AppUser(
          uid: 'seller-preview',
          email: 'seller@example.com',
          nickname: '사장님',
          role: UserRole.seller,
          storeName: '신구 베이커리',
        ),
      ),
    ),
  );
}
