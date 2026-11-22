import 'dart:async';

import 'package:flutter/material.dart';

import 'package:mp_agency/core/theme/app_theme.dart';
import 'package:mp_agency/features/auth/models/app_user.dart';
import 'package:mp_agency/features/home/screens/buyer_home_screen.dart';
import 'package:mp_agency/features/mypage/screens/my_page_screen.dart';
import 'package:mp_agency/features/mypage/services/profile_service.dart';
import 'package:mp_agency/features/nearby/screens/nearby_screen.dart';
import 'package:mp_agency/features/reservation/screens/reservation_list_screen.dart';
import 'package:mp_agency/features/reservation/services/reservation_service.dart';
import 'package:mp_agency/features/sync/widgets/sync_gate.dart';

/// 구매자 하단 탭 번호
class BuyerTab {
  static const home = 0;
  static const nearby = 1;
  static const reservations = 2;
  static const my = 3;

  /// 다른 화면에서 탭을 바꿀 때 사용 (예: 예약 완료 → 예약 내역)
  static final current = ValueNotifier<int>(home);
}

/// 구매자 하단 탭: 홈 · 내 주변 · 예약 내역 · 나의 다먹음
class BuyerMainScreen extends StatefulWidget {
  const BuyerMainScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<BuyerMainScreen> createState() => _BuyerMainScreenState();
}

class _BuyerMainScreenState extends State<BuyerMainScreen> {
  int _index = BuyerTab.home;

  /// 1분마다 픽업 마감 확인 (30분 전 알림, 노쇼 처리)
  late final Timer _deadlineTimer;

  @override
  void initState() {
    super.initState();
    ProfileService.instance.start(widget.user);
    ReservationService.instance.checkDeadlines();
    _deadlineTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => ReservationService.instance.checkDeadlines(),
    );
    BuyerTab.current.value = BuyerTab.home;
    BuyerTab.current.addListener(_onTabRequested);
  }

  @override
  void dispose() {
    _deadlineTimer.cancel();
    BuyerTab.current.removeListener(_onTabRequested);
    super.dispose();
  }

  void _onTabRequested() => setState(() => _index = BuyerTab.current.value);

  void _select(int i) {
    BuyerTab.current.value = i; // 리스너가 _index를 바꿈
  }

  @override
  Widget build(BuildContext context) {
    // 첫 데이터(Firestore)를 받은 뒤에 탭 화면을 그림
    return SyncGate(user: widget.user, builder: _buildTabs);
  }

  Widget _buildTabs(BuildContext context) {
    final pages = [
      BuyerHomeScreen(user: widget.user),
      NearbyScreen(userId: widget.user.uid),
      ReservationListScreen(
        userId: widget.user.uid,
        onBrowseFood: () => _select(BuyerTab.home),
      ),
      MyPageScreen(user: widget.user),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
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
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: AppColors.orange),
            label: '홈',
          ),
          NavigationDestination(
            icon: Icon(Icons.place_outlined),
            selectedIcon: Icon(Icons.place, color: AppColors.orange),
            label: '내 주변',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long, color: AppColors.orange),
            label: '예약 내역',
          ),
          NavigationDestination(
            icon: Icon(Icons.sentiment_satisfied_outlined),
            selectedIcon: Icon(
              Icons.sentiment_satisfied_alt,
              color: AppColors.orange,
            ),
            label: '나의 다먹음',
          ),
        ],
      ),
    );
  }
}
