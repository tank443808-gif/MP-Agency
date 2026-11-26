import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:mp_agency/core/theme/app_theme.dart';
import 'package:mp_agency/features/location/services/location_service.dart';
import 'package:mp_agency/features/product/services/product_service.dart';
import 'package:mp_agency/features/store/models/store.dart';
import 'package:mp_agency/features/store/services/store_service.dart';

/// 판매자 매장 위치 설정 (stores.latitude · longitude · address)
///
/// 지도를 눌러 핀을 옮기거나 "현재 위치로"를 누르면, 그 자리의 주소를 찾아 채워 줌.
/// 저장하면 손님 화면의 지도·거리와 판매 중인 상품의 픽업 위치가 함께 바뀜.
class StoreLocationScreen extends StatefulWidget {
  const StoreLocationScreen({super.key, required this.store});

  final Store store;

  @override
  State<StoreLocationScreen> createState() => _StoreLocationScreenState();
}

class _StoreLocationScreenState extends State<StoreLocationScreen> {
  final _map = MapController();
  late LatLng _point = LatLng(widget.store.latitude, widget.store.longitude);
  late final _address = TextEditingController(text: widget.store.address);
  bool _finding = false;
  bool _locating = false;

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  /// 핀을 옮기고 그 자리의 주소 찾기
  Future<void> _moveTo(LatLng p, {bool moveMap = false}) async {
    setState(() {
      _point = p;
      _finding = true;
    });
    if (moveMap) _map.move(p, 17);
    final found = await LocationService.instance.fullAddress(
      p.latitude,
      p.longitude,
    );
    if (!mounted || _point != p) return;
    setState(() {
      _finding = false;
      if (found != null) _address.text = found;
    });
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    final loc = await LocationService.instance.current(refresh: true);
    if (!mounted) return;
    setState(() => _locating = false);
    if (loc.isFallback) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('현재 위치를 찾지 못했어요. 지도를 눌러 직접 골라 주세요.')),
      );
      return;
    }
    await _moveTo(LatLng(loc.latitude, loc.longitude), moveMap: true);
  }

  void _save() {
    final address = _address.text.trim();
    if (address.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('주소를 입력해 주세요.')));
      return;
    }
    final updated = widget.store.copyWith(
      latitude: _point.latitude,
      longitude: _point.longitude,
      address: address,
    );
    StoreService.instance.update(updated);
    ProductService.instance.syncStore(updated);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('매장 위치를 저장했어요. 손님 지도에 바로 반영돼요.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('매장 위치')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Text('손님이 찾아올 곳을 알려 주세요', style: AppFonts.display(size: 22)),
          const SizedBox(height: 4),
          const Text(
            '지도를 눌러 핀을 옮기면 주소가 자동으로 채워져요.',
            style: TextStyle(fontSize: 13, color: AppColors.subText),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: SizedBox(
              height: 340,
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _map,
                    options: MapOptions(
                      initialCenter: _point,
                      initialZoom: 17,
                      onTap: (_, p) => _moveTo(p),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.mp_agency',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _point,
                            width: 48,
                            height: 48,
                            alignment: Alignment.topCenter,
                            child: const Icon(
                              Icons.location_on_rounded,
                              color: AppColors.urgent,
                              size: 48,
                            ),
                          ),
                        ],
                      ),
                      const RichAttributionWidget(
                        attributions: [
                          TextSourceAttribution('OpenStreetMap contributors'),
                        ],
                      ),
                    ],
                  ),
                  Positioned(
                    right: 10,
                    top: 10,
                    child: Material(
                      color: Colors.white,
                      shape: const StadiumBorder(),
                      elevation: 3,
                      child: TextButton.icon(
                        onPressed: _locating ? null : _useCurrentLocation,
                        icon: _locating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.my_location_rounded,
                                color: Color(0xFF3D8BFF),
                              ),
                        label: const Text('현재 위치로'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('주소', style: AppFonts.display(size: 14)),
              const SizedBox(width: 8),
              if (_finding)
                const Text(
                  '주소 찾는 중…',
                  style: TextStyle(fontSize: 12, color: AppColors.subText),
                ),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _address,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: '예: 경기 성남시 중원구 광명로 377 1층',
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '동·호수나 층 같은 상세 위치는 직접 덧붙여 주세요.',
            style: TextStyle(fontSize: 12, color: AppColors.subText),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: FilledButton(
            onPressed: _finding ? null : _save,
            child: const Text('이 위치로 저장'),
          ),
        ),
      ),
    );
  }
}
