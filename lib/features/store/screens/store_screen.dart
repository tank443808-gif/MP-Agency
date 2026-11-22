import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:mp_agency/core/theme/app_theme.dart';
import 'package:mp_agency/core/utils/formatters.dart';
import 'package:mp_agency/features/favorite/widgets/favorite_button.dart';
import 'package:mp_agency/features/location/services/location_service.dart';
import 'package:mp_agency/features/product/models/product.dart';
import 'package:mp_agency/features/product/screens/product_detail_screen.dart';
import 'package:mp_agency/features/product/services/product_service.dart';
import 'package:mp_agency/features/product/widgets/product_card.dart';
import 'package:mp_agency/features/store/models/store.dart';
import 'package:mp_agency/features/store/services/store_service.dart';

/// 매장 상세: 매장 정보 · 찜 · 지금 판매 중인 상품
class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key, required this.storeId, required this.userId});

  final String storeId;
  final String userId;

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  late final Stream<List<Product>> _products = ProductService.instance
      .watchOnSale();
  DateTime _now = DateTime.now();
  late final Timer _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(
      const Duration(seconds: 30),
      (_) => setState(() => _now = DateTime.now()),
    );
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  int? _distanceTo(double lat, double lng) {
    final loc = LocationService.instance.last;
    if (loc == null) return null;
    return LocationService.instance.distanceMeters(
      loc.latitude,
      loc.longitude,
      lat,
      lng,
    );
  }

  Future<void> _openMap(Store s) async {
    final uri = Uri.parse(
      'https://map.kakao.com/link/to/'
      '${Uri.encodeComponent(s.name)},${s.latitude},${s.longitude}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreService.instance.findById(widget.storeId);
    if (store == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('매장을 찾을 수 없어요.')),
      );
    }
    final distance = _distanceTo(store.latitude, store.longitude);

    return Scaffold(
      appBar: AppBar(
        title: Text(store.name),
        actions: [
          FavoriteButton(
            userId: widget.userId,
            storeId: store.id,
            background: null,
          ),
        ],
      ),
      body: StreamBuilder<List<Product>>(
        stream: _products,
        builder: (context, snap) {
          final items = (snap.data ?? const <Product>[])
              .where((p) => p.storeId == store.id)
              .toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              _StoreHeader(store: store, distance: distance),
              const SizedBox(height: 16),
              _InfoCard(store: store, onMap: () => _openMap(store)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Text('지금 구할 수 있는 음식', style: AppFonts.display(size: 18)),
                  const SizedBox(width: 6),
                  Text(
                    '${items.length}',
                    style: AppFonts.display(size: 18, color: AppColors.orange),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (!store.isOpen)
                const _Notice(text: '지금은 영업 준비 중이에요. 조금 뒤에 다시 들러 주세요!')
              else if (items.isEmpty)
                const _Notice(text: '오늘은 남은 음식을 모두 구했어요. 내일 또 만나요! 🌱')
              else
                for (final p in items)
                  ProductCard(
                    product: p,
                    now: _now,
                    distanceMeters: distance,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ProductDetailScreen(
                          product: p,
                          userId: widget.userId,
                          distanceMeters: distance,
                        ),
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _StoreHeader extends StatelessWidget {
  const _StoreHeader({required this.store, this.distance});

  final Store store;
  final int? distance;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            store.category.color,
            Color.lerp(store.category.color, Colors.white, 0.6)!,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              shape: BoxShape.circle,
            ),
            child: Text(
              store.displayEmoji,
              style: const TextStyle(fontSize: 38),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _OpenBadge(isOpen: store.isOpen),
                const SizedBox(height: 6),
                Text(store.name, style: AppFonts.display(size: 22)),
                const SizedBox(height: 2),
                Text(
                  [
                    store.category.label,
                    if (distance != null) formatDistance(distance!),
                  ].join(' · '),
                  style: const TextStyle(fontSize: 13, color: AppColors.text),
                ),
                if (store.description != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    store.description!,
                    style: const TextStyle(fontSize: 12, height: 1.4),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OpenBadge extends StatelessWidget {
  const _OpenBadge({required this.isOpen});

  final bool isOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isOpen ? AppColors.deepGreen : AppColors.subText,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isOpen ? '영업 중' : '준비 중',
        style: AppFonts.display(size: 11, color: Colors.white),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.store, required this.onMap});

  final Store store;
  final VoidCallback onMap;

  @override
  Widget build(BuildContext context) {
    Widget line(IconData icon, String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.subText),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              children: [
                line(Icons.place_outlined, store.address),
                line(Icons.schedule, '영업시간 ${store.hours}'),
                if (store.pickupGuide != null)
                  line(Icons.info_outline_rounded, store.pickupGuide!),
                if (store.contactPhone != null)
                  line(Icons.call_outlined, store.contactPhone!),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onMap,
            style: TextButton.styleFrom(foregroundColor: AppColors.orange),
            icon: const Icon(Icons.near_me_outlined, size: 16),
            label: const Text('길찾기'),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.paleGreen,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(text, style: const TextStyle(fontSize: 13)),
    );
  }
}
