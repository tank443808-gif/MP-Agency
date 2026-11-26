// 모든 화면을 휴대폰 크기로 그려 보고 "넘침(overflow)" 오류가 있는지 검사하는 테스트.
//
// 실행: flutter test test/overflow_test.dart
//
// 실제 글꼴(주아·고운돋움·Noto Sans KR)은 테스트에서 인터넷으로 받을 수 없어서
// 크기가 비슷한 Windows 한글 글꼴(맑은 고딕)으로 대신 그립니다.
// 맑은 고딕이 없으면(맥 등) 기본 테스트 글꼴로 그려 정확도가 조금 떨어집니다.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mp_agency/core/theme/app_theme.dart';
import 'package:mp_agency/features/auth/models/app_user.dart';
import 'package:mp_agency/features/auth/screens/login_screen.dart';
import 'package:mp_agency/features/auth/screens/signup_screen.dart';
import 'package:mp_agency/features/favorite/screens/favorite_list_screen.dart';
import 'package:mp_agency/features/favorite/services/favorite_service.dart';
import 'package:mp_agency/features/home/screens/buyer_home_screen.dart';
import 'package:mp_agency/features/mypage/screens/my_page_screen.dart';
import 'package:mp_agency/features/mypage/screens/profile_screen.dart';
import 'package:mp_agency/features/mypage/services/profile_service.dart';
import 'package:mp_agency/features/nearby/screens/nearby_screen.dart';
import 'package:mp_agency/features/notification/screens/notification_screen.dart';
import 'package:mp_agency/features/product/models/product.dart';
import 'package:mp_agency/features/product/screens/product_detail_screen.dart';
import 'package:mp_agency/features/product/screens/product_form_screen.dart';
import 'package:mp_agency/features/product/screens/product_manage_screen.dart';
import 'package:mp_agency/features/product/services/product_service.dart';
import 'package:mp_agency/features/reservation/models/reservation.dart';
import 'package:mp_agency/features/reservation/screens/pickup_complete_screen.dart';
import 'package:mp_agency/features/reservation/screens/reservation_complete_screen.dart';
import 'package:mp_agency/features/reservation/screens/reservation_detail_screen.dart';
import 'package:mp_agency/features/reservation/screens/reservation_list_screen.dart';
import 'package:mp_agency/features/reservation/screens/seller_reservation_screen.dart';
import 'package:mp_agency/features/reservation/services/reservation_service.dart';
import 'package:mp_agency/features/seller_dashboard/screens/seller_dashboard_screen.dart';
import 'package:mp_agency/features/store/models/store.dart';
import 'package:mp_agency/features/store/screens/my_store_screen.dart';
import 'package:mp_agency/features/store/screens/store_location_screen.dart';
import 'package:mp_agency/features/store/screens/store_screen.dart';
import 'package:mp_agency/features/store/services/store_service.dart';

const _buyer = AppUser(
  uid: 'test-buyer',
  email: 'buyer@example.com',
  nickname: '테스트손님님',
  role: UserRole.customer,
);
const _seller = AppUser(
  uid: 'test-seller',
  email: 'seller@example.com',
  nickname: '사장님',
  role: UserRole.seller,
  storeName: '신구 베이커리',
);

/// 검사할 휴대폰 화면 너비 (작은 안드로이드 · 아이폰 미니 · 일반)
const _widths = [360.0, 375.0];

Future<void> _loadKoreanFont() async {
  final file = File(r'C:\Windows\Fonts\malgun.ttf');
  if (!file.existsSync()) return;
  final bytes = file.readAsBytesSync();
  final families = {
    GoogleFonts.jua().fontFamily!,
    GoogleFonts.gowunDodum().fontFamily!,
    GoogleFonts.notoSansKr().fontFamily!,
    'Roboto',
  };
  for (final family in families) {
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.view(bytes.buffer)));
    await loader.load();
  }
}

/// [screen]을 그려서 넘침 오류 메시지를 모아 돌려줌
Future<List<String>> _render(
  WidgetTester tester,
  Widget screen, {
  required double width,
}) async {
  final problems = <String>[];
  final oldHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    final msg = details.exceptionAsString();
    if (msg.contains('overflowed')) {
      problems.add(msg.split('\n').first);
    }
  };

  // 세로로 길게 그려서 목록 아래쪽까지 모두 만들어지게 함
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 3200);

  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: Material(child: screen),
    ),
  );
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }

  // 화면을 치워서 타이머 정리
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
  FlutterError.onError = oldHandler;
  return problems;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late Reservation reserved;
  late Reservation pickedUp;
  late Reservation cancelled;

  setUpAll(() async {
    await _loadKoreanFont();
    // 예약 내역·나의 다먹음에 내용이 있도록 예약 2개 만들고 1개는 수령 완료
    final products = ProductService.instance.onSale();
    reserved = await ReservationService.instance.reserve(
      userId: _buyer.uid,
      product: products.first,
      quantity: 1,
    );
    final second = await ReservationService.instance.reserve(
      userId: _buyer.uid,
      product: products[1],
      quantity: 2,
    );
    pickedUp = await ReservationService.instance.markPickedUp(second.id);
    final third = await ReservationService.instance.reserve(
      userId: _buyer.uid,
      product: products[2],
      quantity: 1,
    );
    cancelled = await ReservationService.instance.cancel(
      third.id,
      reason: CancelReason.productIssue,
    );
    ProfileService.instance.start(_buyer);
    FavoriteService.instance.toggle(_buyer.uid, 's1');
    FavoriteService.instance.toggle(_buyer.uid, 's3');
  });

  Store store() => StoreService.instance.storeOf(_seller);
  Product longNameProduct() => ProductService.instance.onSale().reduce(
    (a, b) => a.name.length >= b.name.length ? a : b,
  );

  final screens = <String, Widget Function()>{
    '로그인': () => const LoginScreen(),
    '회원가입': () => const SignupScreen(),
    '구매자 홈': () => const BuyerHomeScreen(user: _buyer),
    '내 주변': () => const NearbyScreen(userId: 'test-buyer'),
    '예약 내역': () => const ReservationListScreen(userId: 'test-buyer'),
    '나의 다먹음': () => const MyPageScreen(user: _buyer),
    '상품 상세 (긴 이름)': () => ProductDetailScreen(
      product: longNameProduct(),
      userId: _buyer.uid,
      distanceMeters: 1234,
    ),
    '매장 상세': () => StoreScreen(storeId: 's2', userId: _buyer.uid),
    '찜 목록': () => FavoriteListScreen(userId: _buyer.uid),
    '알림': () => NotificationScreen(userId: _buyer.uid),
    '예약 완료': () => ReservationCompleteScreen(reservation: reserved),
    '예약 상세': () => ReservationDetailScreen(reservation: reserved),
    '수령 완료': () => PickupCompleteScreen(reservation: pickedUp),
    '취소된 예약 상세 (환불 표시)': () => ReservationDetailScreen(reservation: cancelled),
    '프로필·설정': () => const ProfileScreen(),
    '판매자 대시보드': () =>
        SellerDashboardScreen(user: _seller, store: store(), onGoTab: (_) {}),
    '상품 관리': () => ProductManageScreen(store: store()),
    '상품 등록': () => ProductFormScreen(store: store()),
    '상품 수정': () => ProductFormScreen(
      store: store(),
      product: ProductService.instance.byStore(store().id).first,
    ),
    '예약 관리': () => SellerReservationScreen(store: store()),
    '내 가게': () => MyStoreScreen(storeId: store().id),
    '매장 위치 설정': () => StoreLocationScreen(store: store()),
  };

  for (final width in _widths) {
    for (final entry in screens.entries) {
      testWidgets('${entry.key} · 너비 ${width.toInt()}', (tester) async {
        final problems = await _render(tester, entry.value(), width: width);
        expect(problems, isEmpty, reason: problems.join('\n'));
      });
    }
  }
}
