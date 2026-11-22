import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:mp_agency/core/theme/app_theme.dart';
import 'package:mp_agency/features/auth/models/app_user.dart';
import 'package:mp_agency/features/home/widgets/category_menu.dart';
import 'package:mp_agency/features/home/widgets/home_banner.dart';
import 'package:mp_agency/features/home/widgets/home_header.dart';
import 'package:mp_agency/features/home/widgets/home_search_bar.dart';
import 'package:mp_agency/features/home/widgets/home_tip_box.dart';
import 'package:mp_agency/features/home/widgets/quick_filter_chips.dart';
import 'package:mp_agency/features/location/models/user_location.dart';
import 'package:mp_agency/features/location/services/location_service.dart';
import 'package:mp_agency/features/location/widgets/location_picker_sheet.dart';
import 'package:mp_agency/features/mypage/services/profile_service.dart';
import 'package:mp_agency/features/product/models/product.dart';
import 'package:mp_agency/features/product/screens/product_detail_screen.dart';
import 'package:mp_agency/features/product/services/product_service.dart';
import 'package:mp_agency/features/notification/widgets/notification_bell.dart';
import 'package:mp_agency/features/product/widgets/product_card.dart';
import 'package:mp_agency/features/recommendation/services/behavior_service.dart';
import 'package:mp_agency/features/recommendation/services/recommendation_service.dart';
import 'package:mp_agency/features/recommendation/widgets/recommendation_section.dart';

/// 구매자 홈: 배너 · 검색 · 카테고리 · 빠른 필터 · 맞춤 추천 · 지금 마감 임박 목록
/// (하단 탭은 BuyerMainScreen이 담당)
class BuyerHomeScreen extends StatefulWidget {
  const BuyerHomeScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<BuyerHomeScreen> createState() => _BuyerHomeScreenState();
}

class _BuyerHomeScreenState extends State<BuyerHomeScreen> {
  /// 필터 없이 볼 때 처음 보여줄 개수
  static const _previewCount = 3;

  final _searchController = TextEditingController();
  late final Stream<List<Product>> _products = ProductService.instance
      .watchOnSale();

  ProductCategory? _category;
  String _query = '';
  bool _showAll = false;
  QuickFilters _filters = const QuickFilters();
  Timer? _searchLog;

  /// 남은 시간 표시를 갱신하기 위한 현재 시각
  DateTime _now = DateTime.now();
  late final Timer _ticker;

  /// GPS 현재 위치 (가져오는 중이면 null)
  UserLocation? _location;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    LocationService.instance.location.addListener(_onLocationChanged);
    _loadLocation();
    _ticker = Timer.periodic(
      const Duration(seconds: 30),
      (_) => setState(() => _now = DateTime.now()),
    );
  }

  @override
  void dispose() {
    LocationService.instance.location.removeListener(_onLocationChanged);
    _ticker.cancel();
    _searchLog?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// 다른 화면(지역 선택 등)에서 위치가 바뀌면 따라 바꿈
  void _onLocationChanged() {
    final loc = LocationService.instance.last;
    if (loc != null && mounted) setState(() => _location = loc);
  }

  /// 위치 누르기: 현재 위치(GPS) 또는 지역 선택
  Future<void> _chooseLocation() async {
    final useGps = await showLocationPicker(context);
    if (useGps) await _loadLocation();
  }

  Future<void> _loadLocation() async {
    if (_locating) return;
    setState(() => _locating = true);
    final loc = await LocationService.instance.current(refresh: true);
    if (!mounted) return;
    setState(() {
      _location = loc;
      _locating = false;
    });
    if (loc.status == LocationStatus.denied ||
        loc.status == LocationStatus.serviceDisabled) {
      _showLocationHelp(loc.status);
    }
  }

  void _showLocationHelp(LocationStatus status) {
    final String msg;
    if (status == LocationStatus.serviceDisabled) {
      msg = '기기의 위치(GPS)가 꺼져 있어 기본 위치로 보여드려요.';
    } else if (kIsWeb) {
      msg =
          '위치 권한이 없어 기본 위치로 보여드려요.\n'
          '주소창 왼쪽 아이콘에서 위치를 허용한 뒤 위치를 눌러 주세요.';
    } else {
      msg = '위치 권한이 없어 기본 위치로 보여드려요.';
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          action: kIsWeb
              ? null
              : SnackBarAction(
                  label: '설정',
                  onPressed: () =>
                      LocationService.instance.openSettings(status),
                ),
        ),
      );
  }

  String get _locationHint {
    final loc = _location;
    if (loc == null) return '지금 픽업 가능한 음식을 보여드려요';
    switch (loc.status) {
      case LocationStatus.current:
        return '내 주변 픽업 가능한 음식이에요';
      case LocationStatus.denied:
        return '위치 권한을 허용해 주세요';
      case LocationStatus.serviceDisabled:
        return 'GPS를 켜 주세요';
      case LocationStatus.error:
        return '위치를 못 찾았어요 · 눌러서 다시 시도';
      case LocationStatus.selected:
        return '고른 지역 주변 음식이에요 · 눌러서 변경';
    }
  }

  int? _distanceTo(Product p) {
    final loc = _location;
    if (loc == null) return null;
    return LocationService.instance.distanceMeters(
      loc.latitude,
      loc.longitude,
      p.storeLatitude,
      p.storeLongitude,
    );
  }

  void _openDetail(Product p, {bool fromRecommendation = false}) {
    if (fromRecommendation) {
      BehaviorService.instance.record(
        userId: widget.user.uid,
        type: BehaviorType.clickRecommendation,
        product: p,
      );
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(
          product: p,
          userId: widget.user.uid,
          distanceMeters: _distanceTo(p),
        ),
      ),
    );
  }

  bool get _isFiltering =>
      _category != null || _query.isNotEmpty || _filters.any;

  void _onSearch(String v) {
    setState(() => _query = v);
    // 입력이 멈추면 검색 기록 남기기 (추천 분석용)
    _searchLog?.cancel();
    if (v.trim().length < 2) return;
    _searchLog = Timer(const Duration(milliseconds: 900), () {
      BehaviorService.instance.record(
        userId: widget.user.uid,
        type: BehaviorType.search,
        searchQuery: v.trim(),
      );
    });
  }

  void _onCategory(ProductCategory? c) {
    setState(() => _category = c);
    if (c != null) {
      BehaviorService.instance.record(
        userId: widget.user.uid,
        type: BehaviorType.filterCategory,
        category: c,
      );
    }
  }

  List<Product> _applyFilter(List<Product> all) {
    final q = _query.trim().toLowerCase();
    return all.where((p) {
      if (!p.isAvailable(_now)) return false;
      if (_category != null && p.category != _category) return false;
      if (q.isNotEmpty &&
          !p.name.toLowerCase().contains(q) &&
          !p.storeName.toLowerCase().contains(q)) {
        return false;
      }
      if (_filters.price != null &&
          !_filters.price!.contains(p.discountPrice)) {
        return false;
      }
      if (_filters.closingSoon && p.remaining(_now).inMinutes > 60) {
        return false;
      }
      if (_filters.near) {
        final d = _distanceTo(p);
        if (d == null || d > QuickFilters.nearMeters) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: StreamBuilder<List<Product>>(
        stream: _products,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('상품을 불러오지 못했어요.\n${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final available = snap.data!
              .where((p) => p.isAvailable(_now))
              .toList();
          final filtered = _applyFilter(snap.data!);
          final visible = (_isFiltering || _showAll)
              ? filtered
              : filtered.take(_previewCount).toList();
          final profile = RecommendationService.instance.profileOf(
            widget.user.uid,
          );
          final picks = RecommendationService.instance.recommend(
            userId: widget.user.uid,
            products: available,
            now: _now,
            distanceOf: _distanceTo,
            limit: 5,
          );

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              HomeHeader(
                locationName: _location?.label ?? LocationService.fallbackLabel,
                locationHint: _locationHint,
                isLocating: _locating,
                hintIsWarning: _location?.isFallback ?? false,
                trailing: NotificationBell(userId: widget.user.uid),
                onLocationTap: _chooseLocation,
              ),
              const SizedBox(height: 12),
              HomeSearchBar(
                controller: _searchController,
                onChanged: _onSearch,
              ),
              const SizedBox(height: 16),
              HomeBanner(
                rescuableCount: available.length,
                onTap: () => setState(() {
                  _category = null;
                  _query = '';
                  _searchController.clear();
                  _filters = const QuickFilters();
                  _showAll = true;
                }),
              ),
              const SizedBox(height: 20),
              CategoryMenu(selected: _category, onChanged: _onCategory),
              const SizedBox(height: 16),
              QuickFilterChips(
                value: _filters,
                onChanged: (f) => setState(() => _filters = f),
              ),
              const SizedBox(height: 20),
              if (!_isFiltering && picks.isNotEmpty) ...[
                RecommendationSection(
                  nickname:
                      ProfileService.instance.current.value?.nickname ??
                      widget.user.nickname,
                  items: picks,
                  hasHistory: profile.hasHistory,
                  onTap: (r) =>
                      _openDetail(r.product, fromRecommendation: true),
                ),
                const SizedBox(height: 24),
              ],
              _SectionTitle(
                title: _category == null
                    ? '🔥 지금 마감 임박'
                    : '${_category!.label} 마감 임박',
                actionLabel: _isFiltering ? null : (_showAll ? '접기' : '전체보기'),
                onAction: () => setState(() => _showAll = !_showAll),
              ),
              const SizedBox(height: 4),
              if (visible.isEmpty)
                const _EmptyProducts()
              else
                for (final p in visible)
                  ProductCard(
                    product: p,
                    now: _now,
                    distanceMeters: _distanceTo(p),
                    onTap: () => _openDetail(p),
                  ),
              const SizedBox(height: 16),
              const HomeTipBox(),
            ],
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: AppFonts.display(size: 20)),
        const Spacer(),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(foregroundColor: AppColors.subText),
            child: Text('$actionLabel ›'),
          ),
      ],
    );
  }
}

class _EmptyProducts extends StatelessWidget {
  const _EmptyProducts();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          Text('🍽️', style: TextStyle(fontSize: 40)),
          SizedBox(height: 8),
          Text(
            '지금 조건에 맞는 음식이 없어요.\n다른 카테고리도 둘러보세요!',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.subText),
          ),
        ],
      ),
    );
  }
}
