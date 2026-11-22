import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:mp_agency/core/theme/app_theme.dart';
import 'package:mp_agency/core/utils/formatters.dart';
import 'package:mp_agency/core/widgets/pill_chip.dart';
import 'package:mp_agency/features/location/models/user_location.dart';
import 'package:mp_agency/features/location/services/location_service.dart';
import 'package:mp_agency/features/location/widgets/location_picker_sheet.dart';
import 'package:mp_agency/features/product/models/product.dart';
import 'package:mp_agency/features/product/screens/product_detail_screen.dart';
import 'package:mp_agency/features/product/services/product_service.dart';
import 'package:mp_agency/features/product/widgets/product_card.dart';
import 'package:mp_agency/features/store/models/store.dart';
import 'package:mp_agency/features/store/screens/store_screen.dart';
import 'package:mp_agency/features/store/services/store_service.dart';

/// 내 주변 탭 (기능명세 SRCH-005 위치 기반 검색)
/// 내 위치가 가운데인 지도 + 가까운 매장 목록. 매장을 고르면 지도에서 강조하고
/// 목록 자리에 그 매장의 판매 음식을 보여줌 (✕로 매장 목록 복귀).
class NearbyScreen extends StatefulWidget {
  const NearbyScreen({super.key, required this.userId});

  final String userId;

  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

/// 매장 + 지금 판매 중인 상품 + 거리
class _StoreSpot {
  _StoreSpot(this.store, this.products, this.distance);
  final Store store;
  final List<Product> products;
  final int distance;

  int get minPrice =>
      products.map((p) => p.discountPrice).reduce((a, b) => a < b ? a : b);
  int get maxDiscount =>
      products.map((p) => p.discountRate).reduce((a, b) => a > b ? a : b);
}

class _NearbyScreenState extends State<NearbyScreen> {
  /// 내 주변이 한눈에 보이는 확대 수준
  static const _aroundZoom = 15.5;

  final _map = MapController();
  late final Stream<List<Product>> _products = ProductService.instance
      .watchOnSale();

  UserLocation? _location;
  ProductCategory? _category;
  String? _selectedStoreId;
  bool _mapReady = false;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    LocationService.instance.location.addListener(_onLocationChanged);
    LocationService.instance.current().then((loc) {
      if (!mounted) return;
      setState(() => _location = loc);
      // GPS 위치를 받으면 내 위치를 지도 가운데로
      if (_selectedStoreId == null) _centerOnMe();
    });
  }

  @override
  void dispose() {
    LocationService.instance.location.removeListener(_onLocationChanged);
    super.dispose();
  }

  /// 홈에서 지역을 바꾸면 지도도 그 위치로
  void _onLocationChanged() {
    final loc = LocationService.instance.last;
    if (loc == null || !mounted) return;
    setState(() {
      _location = loc;
      _selectedStoreId = null;
    });
    _centerOnMe();
  }

  /// 위치 바꾸기 (현재 위치 또는 지역 선택)
  Future<void> _chooseLocation() async {
    final useGps = await showLocationPicker(context);
    if (useGps) await LocationService.instance.current(refresh: true);
  }

  LatLng get _me => LatLng(
    _location?.latitude ?? LocationService.fallbackLatitude,
    _location?.longitude ?? LocationService.fallbackLongitude,
  );

  void _centerOnMe() {
    if (_mapReady) _map.move(_me, _aroundZoom);
  }

  List<_StoreSpot> _spots(List<Product> products) {
    final spots = <_StoreSpot>[];
    for (final store in StoreService.instance.all) {
      final items = products
          .where(
            (p) =>
                p.storeId == store.id &&
                (_category == null || p.category == _category),
          )
          .toList();
      if (items.isEmpty) continue;
      final d = LocationService.instance.distanceMeters(
        _me.latitude,
        _me.longitude,
        store.latitude,
        store.longitude,
      );
      spots.add(_StoreSpot(store, items, d));
    }
    spots.sort((a, b) => a.distance.compareTo(b.distance));
    return spots;
  }

  /// 매장 선택: 지도에서 강조하고, 내 위치와 매장이 함께 보이게 이동
  void _select(_StoreSpot spot) {
    setState(() {
      _selectedStoreId = spot.store.id;
      _now = DateTime.now();
    });
    if (!_mapReady) return;
    final store = LatLng(spot.store.latitude, spot.store.longitude);
    _map.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds(_me, store),
        padding: const EdgeInsets.fromLTRB(90, 120, 90, 50),
        maxZoom: 17,
      ),
    );
  }

  /// ✕: 다시 매장 목록으로, 지도는 내 위치 가운데로
  void _clearSelection() {
    setState(() => _selectedStoreId = null);
    _centerOnMe();
  }

  void _openStore(String storeId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StoreScreen(storeId: storeId, userId: widget.userId),
      ),
    );
  }

  void _openProduct(Product p, int distance) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(
          product: p,
          userId: widget.userId,
          distanceMeters: distance,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: StreamBuilder<List<Product>>(
        stream: _products,
        builder: (context, snap) {
          final spots = _spots(snap.data ?? const []);
          final selected = spots
              .where((s) => s.store.id == _selectedStoreId)
              .firstOrNull;
          final storePoint = selected == null
              ? null
              : LatLng(selected.store.latitude, selected.store.longitude);

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              InkWell(
                onTap: _chooseLocation,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _location == null ? '위치 찾는 중…' : '${_location!.label} 근처',
                      style: AppFonts.display(
                        size: 13,
                        color: AppColors.urgent,
                      ),
                    ),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: AppColors.urgent,
                    ),
                  ],
                ),
              ),
              Text('오늘의 한 끼를 찾아요.', style: AppFonts.display(size: 26)),
              const SizedBox(height: 14),
              _CategoryChips(
                selected: _category,
                onChanged: (c) {
                  setState(() => _category = c);
                  if (_selectedStoreId != null) _clearSelection();
                },
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: SizedBox(
                  height: 320,
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: _map,
                        options: MapOptions(
                          initialCenter: _me,
                          initialZoom: _aroundZoom,
                          onMapReady: () {
                            _mapReady = true;
                            if (_location != null) _centerOnMe();
                          },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.mp_agency',
                          ),
                          // 선택한 매장 주변 강조 원
                          if (storePoint != null)
                            CircleLayer(
                              circles: [
                                CircleMarker(
                                  point: storePoint,
                                  radius: 60,
                                  useRadiusInMeter: true,
                                  color: AppColors.orange.withValues(
                                    alpha: 0.18,
                                  ),
                                  borderColor: AppColors.orange,
                                  borderStrokeWidth: 2,
                                ),
                              ],
                            ),
                          // 내 위치 → 선택한 매장 점선
                          if (storePoint != null)
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: [_me, storePoint],
                                  color: AppColors.orange,
                                  strokeWidth: 3,
                                  pattern: StrokePattern.dashed(
                                    segments: const [8, 6],
                                  ),
                                ),
                              ],
                            ),
                          MarkerLayer(
                            markers: [
                              // 선택 안 된 매장 먼저, 선택된 매장은 맨 위에
                              for (final s in [
                                ...spots.where((s) => s != selected),
                                ?selected,
                              ])
                                Marker(
                                  point: LatLng(
                                    s.store.latitude,
                                    s.store.longitude,
                                  ),
                                  width: s == selected ? 150 : 64,
                                  height: s == selected ? 78 : 56,
                                  alignment: Alignment.topCenter,
                                  child: _StorePin(
                                    spot: s,
                                    selected: s == selected,
                                    dimmed: selected != null && s != selected,
                                    onTap: () => _select(s),
                                  ),
                                ),
                              Marker(
                                point: _me,
                                width: 24,
                                height: 24,
                                child: const _MyDot(),
                              ),
                            ],
                          ),
                          const RichAttributionWidget(
                            attributions: [
                              TextSourceAttribution(
                                'OpenStreetMap contributors',
                              ),
                            ],
                          ),
                        ],
                      ),
                      Positioned(
                        right: 10,
                        top: 10,
                        child: Material(
                          color: Colors.white,
                          shape: const CircleBorder(),
                          elevation: 3,
                          child: IconButton(
                            tooltip: '내 위치로',
                            onPressed: _centerOnMe,
                            icon: const Icon(
                              Icons.my_location_rounded,
                              color: Color(0xFF3D8BFF),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              if (selected != null)
                _StoreFoodPanel(
                  spot: selected,
                  now: _now,
                  onClose: _clearSelection,
                  onOpenStore: () => _openStore(selected.store.id),
                  onOpenProduct: (p) => _openProduct(p, selected.distance),
                )
              else ...[
                Row(
                  children: [
                    Text('지금 픽업 가능한 매장', style: AppFonts.display(size: 18)),
                    const SizedBox(width: 6),
                    Text(
                      '${spots.length}',
                      style: AppFonts.display(
                        size: 18,
                        color: AppColors.orange,
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      '가까운 순',
                      style: TextStyle(fontSize: 12, color: AppColors.subText),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (spots.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      '근처에 이 조건의 음식이 없어요.\n다른 카테고리도 둘러보세요!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.subText, height: 1.5),
                    ),
                  ),
                for (final s in spots)
                  _StoreTile(spot: s, onTap: () => _select(s)),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// 매장을 고르면 목록 자리에 나오는 판매 음식 리스트 (✕로 닫기)
class _StoreFoodPanel extends StatelessWidget {
  const _StoreFoodPanel({
    required this.spot,
    required this.now,
    required this.onClose,
    required this.onOpenStore,
    required this.onOpenProduct,
  });

  final _StoreSpot spot;
  final DateTime now;
  final VoidCallback onClose;
  final VoidCallback onOpenStore;
  final ValueChanged<Product> onOpenProduct;

  @override
  Widget build(BuildContext context) {
    final s = spot.store;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          decoration: BoxDecoration(
            color: AppColors.peach,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.orange, width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  s.displayEmoji,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.name, style: AppFonts.display(size: 18)),
                    Text(
                      '${formatDistance(spot.distance)} · '
                      '판매 음식 ${spot.products.length}개',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: onOpenStore,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.urgent,
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('매장 정보'),
              ),
              IconButton(
                tooltip: '매장 목록으로',
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded, color: AppColors.text),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final p in spot.products)
          ProductCard(
            product: p,
            now: now,
            distanceMeters: spot.distance,
            onTap: () => onOpenProduct(p),
          ),
      ],
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.selected, required this.onChanged});

  final ProductCategory? selected;
  final ValueChanged<ProductCategory?> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, ProductCategory? value) {
      final on = selected == value;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: PillChip(
          label: label,
          selected: on,
          onTap: () => onChanged(value),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip('전체', null),
          for (final c in ProductCategory.values) chip(c.label, c),
        ],
      ),
    );
  }
}

class _MyDot extends StatelessWidget {
  const _MyDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF3D8BFF),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
    );
  }
}

/// 지도 위 매장 핀: 그림 + 판매 개수. 선택되면 크게 + 매장 이름.
class _StorePin extends StatelessWidget {
  const _StorePin({
    required this.spot,
    required this.selected,
    required this.dimmed,
    required this.onTap,
  });

  final _StoreSpot spot;
  final bool selected;

  /// 다른 매장이 선택돼서 흐리게
  final bool dimmed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: dimmed ? 0.45 : 1,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: selected ? 10 : 6,
                vertical: selected ? 6 : 4,
              ),
              decoration: BoxDecoration(
                color: selected ? AppColors.orange : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? Colors.white : AppColors.orange,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: selected
                        ? AppColors.orange.withValues(alpha: 0.5)
                        : Colors.black26,
                    blurRadius: selected ? 12 : 4,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    spot.store.displayEmoji,
                    style: TextStyle(fontSize: selected ? 22 : 16),
                  ),
                  const SizedBox(width: 3),
                  if (selected)
                    Flexible(
                      child: Text(
                        spot.store.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.display(size: 13, color: Colors.white),
                      ),
                    )
                  else
                    Text(
                      '${spot.products.length}',
                      style: AppFonts.display(
                        size: 13,
                        color: AppColors.orange,
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_drop_down_rounded,
              color: AppColors.orange,
              size: selected ? 28 : 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreTile extends StatelessWidget {
  const _StoreTile({required this.spot, required this.onTap});

  final _StoreSpot spot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = spot.store;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
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
                    borderRadius: BorderRadius.circular(16),
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
                      Text(s.name, style: AppFonts.display(size: 16)),
                      Text(
                        '${formatDistance(spot.distance)} · '
                        '${spot.products.length}개 판매 중',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.subText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '최대 ${spot.maxDiscount}% · ${formatWon(spot.minPrice)}부터',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.urgent,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.subText),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
