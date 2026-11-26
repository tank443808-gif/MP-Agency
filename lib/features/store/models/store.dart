import 'package:mp_agency/core/data/app_data.dart';
import 'package:mp_agency/features/product/models/product.dart';

/// 매장 정보 (데이터 테이블 기술서 stores 기준)
class Store {
  const Store({
    required this.id,
    required this.name,
    required this.category,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.ownerId,
    this.description,
    this.pickupGuide,
    this.contactPhone,
    this.openTime = '09:00',
    this.closeTime = '21:00',
    this.isOpen = true,
    this.emoji,
  });

  final String id;

  /// 매장 주인 (판매자 회원 uid). 예시 매장은 처음 로그인한 같은 이름의 판매자가 맡음.
  final String? ownerId;
  final String name;

  /// 대표 카테고리
  final ProductCategory category;
  final String address;
  final double latitude;
  final double longitude;
  final String? description;
  final String? pickupGuide;
  final String? contactPhone;
  final String openTime;
  final String closeTime;

  /// 영업 중인지 (판매자가 켜고 끔)
  final bool isOpen;

  /// 매장 운영 상태 (stores.status)
  String get statusCode => isOpen ? 'OPEN' : 'CLOSED';

  /// 매장 대표 그림
  final String? emoji;

  String get displayEmoji => emoji ?? category.emoji;

  String get hours => '$openTime ~ $closeTime';

  Store copyWith({
    String? ownerId,
    String? name,
    ProductCategory? category,
    String? address,
    double? latitude,
    double? longitude,
    String? description,
    String? pickupGuide,
    String? contactPhone,
    String? openTime,
    String? closeTime,
    bool? isOpen,
  }) => Store(
    id: id,
    ownerId: ownerId ?? this.ownerId,
    name: name ?? this.name,
    category: category ?? this.category,
    address: address ?? this.address,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    description: description ?? this.description,
    pickupGuide: pickupGuide ?? this.pickupGuide,
    contactPhone: contactPhone ?? this.contactPhone,
    openTime: openTime ?? this.openTime,
    closeTime: closeTime ?? this.closeTime,
    isOpen: isOpen ?? this.isOpen,
    emoji: emoji,
  );

  // ───────── Firestore 변환 (stores 컬렉션) ─────────

  factory Store.fromMap(String id, Map<String, dynamic> d) => Store(
    id: id,
    ownerId: d['ownerId'] as String?,
    name: d['name'] as String? ?? '',
    category: ProductCategory.fromCode(d['categoryCode'] as String?),
    address: d['address'] as String? ?? '',
    latitude: AppData.toDouble(d['latitude']),
    longitude: AppData.toDouble(d['longitude']),
    description: d['description'] as String?,
    pickupGuide: d['pickupGuide'] as String?,
    contactPhone: d['contactPhone'] as String?,
    openTime: d['openTime'] as String? ?? '09:00',
    closeTime: d['closeTime'] as String? ?? '21:00',
    isOpen: (d['status'] as String? ?? 'OPEN') == 'OPEN',
    emoji: d['emoji'] as String?,
  );

  Map<String, dynamic> toMap() => {
    'ownerId': ownerId,
    'name': name,
    'categoryCode': category.code,
    'address': address,
    'latitude': latitude,
    'longitude': longitude,
    'description': ?description,
    'pickupGuide': ?pickupGuide,
    'contactPhone': ?contactPhone,
    'openTime': openTime,
    'closeTime': closeTime,
    'status': statusCode,
    'emoji': ?emoji,
  };
}
