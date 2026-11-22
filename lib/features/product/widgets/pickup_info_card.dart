import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:mp_agency/core/theme/app_theme.dart';
import 'package:mp_agency/core/utils/formatters.dart';
import 'package:mp_agency/features/product/models/product.dart';

/// "어디서 픽업하나요?" — 매장명 · 주소 · 픽업 안내 · 길찾기
class PickupInfoCard extends StatelessWidget {
  const PickupInfoCard({super.key, required this.product, this.distanceMeters});

  final Product product;
  final int? distanceMeters;

  Future<void> _openMap(BuildContext context) async {
    final p = product;
    // 카카오맵 길찾기 링크 (앱이 없으면 웹으로 열림)
    final uri = Uri.parse(
      'https://map.kakao.com/link/to/'
      '${Uri.encodeComponent(p.storeName)},${p.storeLatitude},${p.storeLongitude}',
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('지도를 열 수 없어요.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = product;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('어디서 픽업하나요?', style: AppFonts.display(size: 16)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _openMap(context),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.orange,
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.near_me_outlined, size: 16),
                label: const Text('길찾기'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFEDE2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.storefront_outlined,
                  color: AppColors.urgent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      distanceMeters == null
                          ? p.storeName
                          : '${p.storeName} · ${formatDistance(distanceMeters!)}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                    if (p.storeAddress != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        p.storeAddress!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.subText,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    _InfoLine(
                      icon: Icons.schedule,
                      text:
                          '${formatTimeRange(p.pickupStartAt, p.pickupDeadline)} 픽업',
                    ),
                    if (p.pickupGuide != null)
                      _InfoLine(
                        icon: Icons.info_outline_rounded,
                        text: p.pickupGuide!,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: AppColors.subText),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: AppColors.text),
            ),
          ),
        ],
      ),
    );
  }
}
