import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:mp_agency/core/data/app_data.dart';

/// 상품 카테고리 (기획서: 베이커리 · 간편식 · 카페 · 식사)
enum ProductCategory {
  bakery(
    'BAKERY',
    '베이커리',
    '🥐',
    Icons.bakery_dining_outlined,
    Color(0xFFFFE3C8),
  ),
  convenience(
    'CONVENIENCE',
    '간편식',
    '🍙',
    Icons.lunch_dining_outlined,
    Color(0xFFFFF0B8),
  ),
  cafe('CAFE', '카페', '☕', Icons.coffee_outlined, Color(0xFFEFE0D2)),
  meal('MEAL', '식사', '🍱', Icons.restaurant, Color(0xFFDDEFC4));

  const ProductCategory(
    this.code,
    this.label,
    this.emoji,
    this.icon,
    this.color,
  );

  /// DB에 저장되는 값
  final String code;
  final String label;

  /// 상품 사진이 없을 때 쓰는 음식 그림
  final String emoji;

  /// 카테고리 메뉴용 선 아이콘
  final IconData icon;

  /// 카테고리 배경색 (파스텔)
  final Color color;

  static ProductCategory fromCode(String? code) => ProductCategory.values
      .firstWhere((c) => c.code == code, orElse: () => ProductCategory.meal);
}

/// 판매 상태 (기획서 수정사항: 판매 상태는 최소화)
enum ProductStatus {
  onSale('ON_SALE', '판매중'),
  soldOut('SOLD_OUT', '품절'),
  ended('ENDED', '판매종료');

  const ProductStatus(this.code, this.label);
  final String code;
  final String label;

  static ProductStatus fromCode(String? code) => ProductStatus.values
      .firstWhere((s) => s.code == code, orElse: () => ProductStatus.onSale);
}

/// 상품 정보 (데이터 테이블 기술서 products 기준, 화면에 필요한 값 위주)
///
/// 매장 이름·주소·위치는 화면에서 바로 쓰기 위해 함께 들고 있음.
class Product {
  const Product({
    required this.id,
    required this.storeId,
    required this.storeName,
    required this.name,
    required this.category,
    required this.originalPrice,
    required this.discountPrice,
    required this.stockQuantity,
    required this.saleEndAt,
    required this.storeLatitude,
    required this.storeLongitude,
    this.initialStock,
    this.imageUrl,
    this.imageBytes,
    this.emoji,
    this.description,
    this.storeAddress,
    this.pickupGuide,
    this.pickupStartAt,
    this.pickupEndAt,
    this.createdAt,
    this.status = ProductStatus.onSale,
  });

  final String id;
  final String storeId;
  final String storeName;
  final String name;
  final ProductCategory category;
  final int originalPrice;
  final int discountPrice;

  /// 지금 남은 재고
  final int stockQuantity;

  /// 처음 등록한 수량 (판매·폐기 통계용). 없으면 남은 재고와 같다고 봄.
  final int? initialStock;
  final DateTime saleEndAt;

  /// 상품 사진 주소 (products.image_url). 서버 저장소를 붙이면 사용.
  final String? imageUrl;

  /// 판매자가 올린 사진 (서버 저장소 연결 전까지 앱 메모리에 보관)
  final Uint8List? imageBytes;

  bool get hasPhoto => imageBytes != null || imageUrl != null;

  /// 사진이 없을 때 보여줄 음식 그림 (없으면 카테고리 그림)
  final String? emoji;

  String get displayEmoji => emoji ?? category.emoji;

  /// 상품 설명 (판매자가 입력)
  final String? description;

  /// 매장 주소 (stores.address)
  final String? storeAddress;

  /// 픽업 안내 (stores.pickup_guide)
  final String? pickupGuide;

  /// 픽업 시작 시각 (products.pickup_start_at). 없으면 예약 즉시 픽업 가능.
  final DateTime? pickupStartAt;

  /// 픽업 마감 시각 (products.pickup_end_at). 없으면 판매 종료 시각까지 픽업.
  final DateTime? pickupEndAt;

  DateTime get pickupDeadline => pickupEndAt ?? saleEndAt;

  /// 아직 픽업 시작 전인지
  bool pickupNotStarted(DateTime now) =>
      pickupStartAt != null && now.isBefore(pickupStartAt!);

  /// 매장 위치 (거리 계산용, 데이터 테이블 stores.latitude/longitude)
  final double storeLatitude;
  final double storeLongitude;
  final DateTime? createdAt;
  final ProductStatus status;

  int get totalStock => initialStock ?? stockQuantity;

  /// 할인율 (%)
  int get discountRate => originalPrice == 0
      ? 0
      : ((originalPrice - discountPrice) * 100 / originalPrice).round();

  /// 절약 금액 (계산 가능한 값이라 DB에 저장하지 않음)
  int get savedAmount => originalPrice - discountPrice;

  Duration remaining(DateTime now) => saleEndAt.difference(now);

  /// 지금 예약 가능한 상품인지
  bool isAvailable(DateTime now) =>
      status == ProductStatus.onSale &&
      stockQuantity > 0 &&
      saleEndAt.isAfter(now);

  /// 판매가 끝났는지 (판매 종료·시간 지남·품절)
  bool isFinished(DateTime now) => !isAvailable(now);

  /// 지금 기준 상태 (시간이 지나면 판매종료로 보여줌)
  ProductStatus displayStatus(DateTime now) {
    if (status == ProductStatus.ended || !saleEndAt.isAfter(now)) {
      return ProductStatus.ended;
    }
    if (stockQuantity <= 0) return ProductStatus.soldOut;
    return ProductStatus.onSale;
  }

  Product copyWith({
    String? storeName,
    String? name,
    ProductCategory? category,
    int? originalPrice,
    int? discountPrice,
    int? stockQuantity,
    int? initialStock,
    DateTime? saleEndAt,
    double? storeLatitude,
    double? storeLongitude,
    String? emoji,
    Uint8List? imageBytes,
    bool clearImage = false,
    String? description,
    String? storeAddress,
    String? pickupGuide,
    DateTime? pickupStartAt,
    DateTime? pickupEndAt,
    ProductStatus? status,
  }) => Product(
    id: id,
    storeId: storeId,
    storeName: storeName ?? this.storeName,
    name: name ?? this.name,
    category: category ?? this.category,
    originalPrice: originalPrice ?? this.originalPrice,
    discountPrice: discountPrice ?? this.discountPrice,
    stockQuantity: stockQuantity ?? this.stockQuantity,
    initialStock: initialStock ?? this.initialStock,
    saleEndAt: saleEndAt ?? this.saleEndAt,
    storeLatitude: storeLatitude ?? this.storeLatitude,
    storeLongitude: storeLongitude ?? this.storeLongitude,
    imageUrl: clearImage ? null : imageUrl,
    imageBytes: clearImage ? null : (imageBytes ?? this.imageBytes),
    emoji: emoji ?? this.emoji,
    description: description ?? this.description,
    storeAddress: storeAddress ?? this.storeAddress,
    pickupGuide: pickupGuide ?? this.pickupGuide,
    pickupStartAt: pickupStartAt ?? this.pickupStartAt,
    pickupEndAt: pickupEndAt ?? this.pickupEndAt,
    createdAt: createdAt,
    status: status ?? this.status,
  );

  /// 재고만 바꾼 복사본 (예약·취소 시 사용). 판매 종료 상태는 유지.
  Product copyWithStock(int stock) => copyWith(
    stockQuantity: stock,
    status: status == ProductStatus.ended
        ? ProductStatus.ended
        : (stock <= 0 ? ProductStatus.soldOut : ProductStatus.onSale),
  );

  // ───────── Firestore 변환 (products 컬렉션) ─────────

  /// Firestore 문서 → 상품
  factory Product.fromMap(String id, Map<String, dynamic> d) => Product(
    id: id,
    storeId: d['storeId'] as String? ?? '',
    storeName: d['storeName'] as String? ?? '',
    name: d['name'] as String? ?? '',
    category: ProductCategory.fromCode(d['categoryCode'] as String?),
    originalPrice: AppData.toInt(d['originalPrice']),
    discountPrice: AppData.toInt(d['discountPrice']),
    stockQuantity: AppData.toInt(d['stockQuantity']),
    initialStock: d['initialStock'] == null
        ? null
        : AppData.toInt(d['initialStock']),
    saleEndAt: AppData.date(d['saleEndAt']) ?? DateTime.now(),
    storeLatitude: AppData.toDouble(d['storeLatitude']),
    storeLongitude: AppData.toDouble(d['storeLongitude']),
    imageUrl: d['imageUrl'] as String?,
    imageBytes: (d['imageBytes'] as Blob?)?.bytes,
    emoji: d['emoji'] as String?,
    description: d['description'] as String?,
    storeAddress: d['storeAddress'] as String?,
    pickupGuide: d['pickupGuide'] as String?,
    pickupStartAt: AppData.date(d['pickupStartAt']),
    pickupEndAt: AppData.date(d['pickupEndAt']),
    createdAt: AppData.date(d['createdAt']),
    status: ProductStatus.fromCode(d['status'] as String?),
  );

  /// 상품 → Firestore 문서. 예약에 함께 저장할 때는 사진을 뺌([includeImage]).
  Map<String, dynamic> toMap({bool includeImage = true}) => {
    'storeId': storeId,
    'storeName': storeName,
    'name': name,
    'categoryCode': category.code,
    'originalPrice': originalPrice,
    'discountPrice': discountPrice,
    'stockQuantity': stockQuantity,
    'initialStock': ?initialStock,
    'saleEndAt': AppData.ts(saleEndAt),
    'storeLatitude': storeLatitude,
    'storeLongitude': storeLongitude,
    'imageUrl': ?imageUrl,
    if (includeImage && imageBytes != null) 'imageBytes': Blob(imageBytes!),
    'emoji': ?emoji,
    'description': ?description,
    'storeAddress': ?storeAddress,
    'pickupGuide': ?pickupGuide,
    'pickupStartAt': ?AppData.ts(pickupStartAt),
    'pickupEndAt': ?AppData.ts(pickupEndAt),
    'createdAt': ?AppData.ts(createdAt),
    'status': status.code,
  };
}
