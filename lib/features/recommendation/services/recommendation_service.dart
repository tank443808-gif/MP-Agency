import 'dart:math';

import 'package:mp_agency/core/utils/formatters.dart';
import 'package:mp_agency/features/product/models/product.dart';
import 'package:mp_agency/features/recommendation/services/behavior_service.dart';

/// 추천 결과 1건
class Recommendation {
  const Recommendation({
    required this.product,
    required this.score,
    required this.reason,
  });

  final Product product;

  /// 0~1 점수 (높을수록 추천)
  final double score;

  /// 추천 이유 (기능명세 AI-004)
  final String reason;
}

/// 사용자 취향 요약 (기능명세 AI-001)
class TasteProfile {
  const TasteProfile({
    required this.categoryWeights,
    required this.averagePrice,
    required this.eventCount,
  });

  /// 카테고리별 관심도 (조회·예약·수령에 가중치를 줘서 합산)
  final Map<ProductCategory, int> categoryWeights;

  /// 관심 상품의 평균 가격 (기록이 없으면 null)
  final int? averagePrice;
  final int eventCount;

  bool get hasHistory => eventCount > 0;

  ProductCategory? get favoriteCategory {
    if (categoryWeights.isEmpty) return null;
    return categoryWeights.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
  }
}

/// 개인 맞춤 음식 추천 (기능명세 AI-001~004)
///
/// 머신러닝 모델 대신, 사용자 행동 기록으로 취향을 계산하고
/// 선호 카테고리·가격대·할인율·마감 시간·거리를 섞은 점수로 정렬합니다.
/// 추천을 누르거나 예약·수령하면 그 기록이 다시 반영돼 추천이 바뀝니다 (AI-005).
class RecommendationService {
  RecommendationService._();
  static final instance = RecommendationService._();

  /// 점수 가중치 (합 1.0)
  static const _wCategory = 0.35;
  static const _wPrice = 0.2;
  static const _wDiscount = 0.2;
  static const _wUrgency = 0.15;
  static const _wDistance = 0.1;

  TasteProfile profileOf(String userId) {
    final events = BehaviorService.instance.of(userId);
    final weights = <ProductCategory, int>{};
    var priceSum = 0;
    var priceWeight = 0;
    for (final e in events) {
      if (e.category != null) {
        weights[e.category!] = (weights[e.category!] ?? 0) + e.type.weight;
      }
      if (e.price != null) {
        priceSum += e.price! * e.type.weight;
        priceWeight += e.type.weight;
      }
    }
    return TasteProfile(
      categoryWeights: weights,
      averagePrice: priceWeight == 0 ? null : (priceSum / priceWeight).round(),
      eventCount: events.length,
    );
  }

  /// 판매 중인 [products] 중에서 추천 순위대로 [limit]개
  List<Recommendation> recommend({
    required String userId,
    required List<Product> products,
    required DateTime now,
    int? Function(Product)? distanceOf,
    Set<String> excludeProductIds = const {},
    int limit = 5,
  }) {
    final profile = profileOf(userId);
    final maxCat = profile.categoryWeights.values.fold<int>(0, max);

    final results = <Recommendation>[];
    for (final p in products) {
      if (!p.isAvailable(now) || excludeProductIds.contains(p.id)) continue;

      final parts = <String, double>{};

      // 1) 선호 카테고리
      final cat = maxCat == 0
          ? 0.0
          : (profile.categoryWeights[p.category] ?? 0) / maxCat;
      parts['category'] = cat * _wCategory;

      // 2) 평소 가격대와 얼마나 비슷한지
      final avg = profile.averagePrice;
      final price = avg == null
          ? 0.5
          : (1 - (p.discountPrice - avg).abs() / max(avg, 1)).clamp(0.0, 1.0);
      parts['price'] = price * _wPrice;

      // 3) 할인율
      parts['discount'] = (p.discountRate / 100) * _wDiscount;

      // 4) 마감 임박 (3시간 이내일수록 높게)
      final mins = p.remaining(now).inMinutes.clamp(0, 180);
      parts['urgency'] = (1 - mins / 180) * _wUrgency;

      // 5) 거리 (2km 이내일수록 높게)
      final d = distanceOf?.call(p);
      parts['distance'] = d == null
          ? 0.5 * _wDistance
          : (1 - d.clamp(0, 2000) / 2000) * _wDistance;

      final score = parts.values.fold<double>(0, (a, b) => a + b);
      results.add(
        Recommendation(
          product: p,
          score: score,
          reason: _reason(p, parts, profile, d),
        ),
      );
    }
    results.sort((a, b) => b.score.compareTo(a.score));
    return results.take(limit).toList();
  }

  /// 점수에 가장 크게 기여한 요소로 추천 이유 만들기
  String _reason(
    Product p,
    Map<String, double> parts,
    TasteProfile profile,
    int? distance,
  ) {
    final candidates = Map<String, double>.from(parts);
    if (!profile.hasHistory) {
      candidates.remove('category');
      candidates.remove('price');
    }
    final top = candidates.entries.reduce((a, b) => a.value >= b.value ? a : b);
    switch (top.key) {
      case 'category':
        return '자주 찾는 ${p.category.label}';
      case 'price':
        return '평소 가격대 ${formatWon(profile.averagePrice ?? p.discountPrice)} 근처';
      case 'urgency':
        return '곧 마감 · ${formatRemaining(p.remaining(DateTime.now()))}';
      case 'distance':
        return distance == null
            ? '가까운 매장'
            : '가까워요 · ${formatDistance(distance)}';
      case 'discount':
      default:
        return '${p.discountRate}% 할인 중';
    }
  }
}
