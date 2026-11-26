import 'dart:async';

import 'package:flutter/material.dart';

import 'package:mp_agency/core/theme/app_theme.dart';
import 'package:mp_agency/features/auth/models/app_user.dart';
import 'package:mp_agency/features/mypage/services/profile_service.dart';
import 'package:mp_agency/features/product/screens/product_form_screen.dart';
import 'package:mp_agency/features/product/screens/product_manage_screen.dart';
import 'package:mp_agency/features/reservation/screens/seller_reservation_screen.dart';
import 'package:mp_agency/features/reservation/services/reservation_service.dart';
import 'package:mp_agency/features/sync/widgets/sync_gate.dart';
import 'package:mp_agency/features/seller_dashboard/screens/seller_dashboard_screen.dart';
import 'package:mp_agency/features/store/models/store.dart';
import 'package:mp_agency/features/store/screens/my_store_screen.dart';
import 'package:mp_agency/features/store/services/store_service.dart';

/// 판매자 하단 탭 번호
class SellerTab {
  static const dashboard = 0;
  static const products = 1;
  static const reservations = 2;
  static const store = 3;

  /// 다른 화면에서 탭을 바꿀 때 사용 (예: 알림 → 예약 관리)
  static final current = ValueNotifier<int>(dashboard);
}

/// 판매자 하단 탭: 대시보드 · 상품 관리 · 예약 관리 · 내 가게
class SellerMainScreen extends StatefulWidget {
  const SellerMainScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<SellerMainScreen> createState() => _SellerMainScreenState();
}

class _SellerMainScreenState extends State<SellerMainScreen> {
  int _index = SellerTab.dashboard;

  /// 로그인한 판매자의 매장 (없으면 회원가입 때 입력한 매장명으로 만듦)
  late final String _storeId = StoreService.instance.storeOf(widget.user).id;

  /// 1분마다 픽업 마감 확인 (노쇼 처리·알림)
  late final Timer _deadlineTimer;

  @override
  void initState() {
    super.initState();
    SellerTab.current.value = SellerTab.dashboard;
    SellerTab.current.addListener(_onTabRequested);
    ProfileService.instance.start(widget.user);
    ReservationService.instance.checkDeadlines();
    _deadlineTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => ReservationService.instance.checkDeadlines(),
    );
  }

  @override
  void dispose() {
    SellerTab.current.removeListener(_onTabRequested);
    _deadlineTimer.cancel();
    super.dispose();
  }

  void _onTabRequested() => setState(() => _index = SellerTab.current.value);

  void _select(int i) => SellerTab.current.value = i;

  @override
  Widget build(BuildContext context) {
    // 첫 데이터(Firestore)를 받은 뒤에 내 매장을 찾고 탭 화면을 그림
    return SyncGate(user: widget.user, builder: _buildTabs);
  }

  Widget _buildTabs(BuildContext context) {
    return StreamBuilder<Store?>(
      stream: StoreService.instance.watchById(_storeId),
      builder: (context, snap) {
        final store = snap.data ?? StoreService.instance.findById(_storeId)!;
        final pages = [
          SellerDashboardScreen(
            user: widget.user,
            store: store,
            onGoTab: _select,
          ),
          ProductManageScreen(store: store),
          SellerReservationScreen(store: store),
          MyStoreScreen(storeId: store.id),
        ];

        return Scaffold(
          body: IndexedStack(index: _index, children: pages),
          floatingActionButton: _index == 1
              ? FloatingActionButton.extended(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ProductFormScreen(store: store),
                    ),
                  ),
                  backgroundColor: AppColors.orange,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(
                    '상품 등록',
                    style: AppFonts.display(size: 15, color: Colors.white),
                  ),
                )
              : null,
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: _select,
            backgroundColor: Colors.white,
            indicatorColor: AppColors.peach,
            labelTextStyle: WidgetStateProperty.resolveWith(
              (states) => AppFonts.display(
                size: 12,
                color: states.contains(WidgetState.selected)
                    ? AppColors.orange
                    : AppColors.subText,
              ),
            ),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard, color: AppColors.orange),
                label: '대시보드',
              ),
              NavigationDestination(
                icon: Icon(Icons.inventory_2_outlined),
                selectedIcon: Icon(Icons.inventory_2, color: AppColors.orange),
                label: '상품 관리',
              ),
              NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long, color: AppColors.orange),
                label: '예약 관리',
              ),
              NavigationDestination(
                icon: Icon(Icons.storefront_outlined),
                selectedIcon: Icon(Icons.storefront, color: AppColors.orange),
                label: '내 가게',
              ),
            ],
          ),
        );
      },
    );
  }
}
