import 'package:mp_agency/core/data/app_data.dart';
import 'package:mp_agency/features/product/models/product.dart';

/// 예약 상태 (기획서: 판매중 → 예약됨 → 수령완료)
enum ReservationStatus {
  reserved('RESERVED', '예약됨'),
  pickedUp('PICKED_UP', '수령완료'),
  cancelled('CANCELLED', '취소됨'),

  /// 픽업 마감까지 받아가지 않음 (노쇼)
  expired('EXPIRED', '기한만료');

  const ReservationStatus(this.code, this.label);

  /// DB에 저장되는 값
  final String code;
  final String label;

  static ReservationStatus fromCode(String? code) =>
      ReservationStatus.values.firstWhere(
        (s) => s.code == code,
        orElse: () => ReservationStatus.reserved,
      );

  /// 아직 픽업을 기다리는 중인지
  bool get isActive => this == ReservationStatus.reserved;
}

/// 취소·만료 사유와 환불 규칙 (기능명세 RSV-005, 기획서 환불 기준)
enum CancelReason {
  customerSimple('CUSTOMER_SIMPLE', '단순 변심', fullRefund: false),
  productIssue('PRODUCT_ISSUE', '상품 하자·정보 불일치', fullRefund: true),
  seller('SELLER', '판매자 사정', fullRefund: true),
  system('SYSTEM', '시스템 오류', fullRefund: true),
  noShow('NO_SHOW', '픽업 시간 지남(노쇼)', fullRefund: false);

  const CancelReason(this.code, this.label, {required this.fullRefund});
  final String code;
  final String label;

  /// 전액 환불이면 true, 환불 불가면 false
  final bool fullRefund;

  String get refundLabel => fullRefund ? '전액 환불' : '환불 불가';

  static CancelReason? fromCode(String? code) =>
      CancelReason.values.where((r) => r.code == code).firstOrNull;
}

/// 예약 정보 (데이터 테이블 기술서 reservations + reservation_items 기준)
///
/// 예약 당시 가격을 따로 저장해서, 나중에 상품 가격이 바뀌어도
/// 결제 금액·절약 금액이 그대로 유지되게 함.
class Reservation {
  const Reservation({
    required this.id,
    required this.reservationNumber,
    required this.pickupCode,
    required this.userId,
    required this.product,
    required this.quantity,
    required this.unitOriginalPrice,
    required this.unitDiscountPrice,
    required this.reservedAt,
    this.status = ReservationStatus.reserved,
    this.cancelledAt,
    this.pickedUpAt,
    this.expiredAt,
    this.cancelReason,
    this.pickupReminded = false,
  });

  final String id;

  /// 예약 번호 (예: DM-1119-1048)
  final String reservationNumber;

  /// 매장에서 말하는 4자리 픽업 번호
  final String pickupCode;
  final String userId;

  /// 예약한 상품 (예약 시점 정보)
  final Product product;
  final int quantity;
  final int unitOriginalPrice;
  final int unitDiscountPrice;
  final DateTime reservedAt;

  /// 저장된 상태. 화면에는 [displayStatus]를 사용.
  final ReservationStatus status;
  final DateTime? cancelledAt;
  final DateTime? pickedUpAt;

  /// 노쇼로 만료 처리된 시각 (reservations.expired_at)
  final DateTime? expiredAt;

  /// 취소·만료 사유
  final CancelReason? cancelReason;

  /// 픽업 마감 전 알림을 보냈는지
  final bool pickupReminded;

  /// 환불 금액 (취소·만료가 아니면 0)
  int get refundAmount => (cancelReason?.fullRefund ?? false) ? totalPrice : 0;

  int get totalOriginalPrice => unitOriginalPrice * quantity;

  /// 결제 금액
  int get totalPrice => unitDiscountPrice * quantity;

  /// 절약 금액 (계산 가능한 값이라 DB에 저장하지 않음)
  int get savedAmount => totalOriginalPrice - totalPrice;

  DateTime get pickupDeadline => product.pickupDeadline;

  /// 지금 기준 상태. 예약됨인데 픽업 마감이 지났으면 기한만료.
  ReservationStatus displayStatus(DateTime now) =>
      status == ReservationStatus.reserved && now.isAfter(pickupDeadline)
      ? ReservationStatus.expired
      : status;

  Reservation copyWith({
    ReservationStatus? status,
    DateTime? cancelledAt,
    DateTime? pickedUpAt,
    DateTime? expiredAt,
    CancelReason? cancelReason,
    bool? pickupReminded,
  }) => Reservation(
    id: id,
    reservationNumber: reservationNumber,
    pickupCode: pickupCode,
    userId: userId,
    product: product,
    quantity: quantity,
    unitOriginalPrice: unitOriginalPrice,
    unitDiscountPrice: unitDiscountPrice,
    reservedAt: reservedAt,
    status: status ?? this.status,
    cancelledAt: cancelledAt ?? this.cancelledAt,
    pickedUpAt: pickedUpAt ?? this.pickedUpAt,
    expiredAt: expiredAt ?? this.expiredAt,
    cancelReason: cancelReason ?? this.cancelReason,
    pickupReminded: pickupReminded ?? this.pickupReminded,
  );

  // ───────── Firestore 변환 (reservations 컬렉션) ─────────
  // 기술서의 reservations + reservation_items를 한 문서로 합침 (예약 1건 = 상품 1종).
  // 예약 당시 상품 정보는 product 필드에 사진만 빼고 저장.

  factory Reservation.fromMap(
    String id,
    Map<String, dynamic> d, {
    Product? currentProduct,
  }) {
    var product = Product.fromMap(
      d['productId'] as String? ?? '',
      Map<String, dynamic>.from(d['product'] as Map? ?? const {}),
    );
    // 사진은 지금 상품에서 가져옴
    if (currentProduct?.imageBytes != null) {
      product = product.copyWith(imageBytes: currentProduct!.imageBytes);
    }
    return Reservation(
      id: id,
      reservationNumber: d['reservationNumber'] as String? ?? '',
      pickupCode: d['pickupCode'] as String? ?? '',
      userId: d['userId'] as String? ?? '',
      product: product,
      quantity: AppData.toInt(d['quantity'], 1),
      unitOriginalPrice: AppData.toInt(d['unitOriginalPrice']),
      unitDiscountPrice: AppData.toInt(d['unitDiscountPrice']),
      reservedAt: AppData.date(d['reservedAt']) ?? DateTime.now(),
      status: ReservationStatus.fromCode(d['status'] as String?),
      cancelledAt: AppData.date(d['cancelledAt']),
      pickedUpAt: AppData.date(d['pickedUpAt']),
      expiredAt: AppData.date(d['expiredAt']),
      cancelReason: CancelReason.fromCode(d['cancelReason'] as String?),
      pickupReminded: d['pickupReminded'] as bool? ?? false,
    );
  }

  /// [storeOwnerId]: 매장 주인도 이 예약을 볼 수 있게 함께 저장 (보안 규칙용)
  Map<String, dynamic> toMap({String? storeOwnerId}) => {
    'reservationNumber': reservationNumber,
    'pickupCode': pickupCode,
    'userId': userId,
    'storeId': product.storeId,
    'storeOwnerId': storeOwnerId,
    'productId': product.id,
    'product': product.toMap(includeImage: false),
    'quantity': quantity,
    'unitOriginalPrice': unitOriginalPrice,
    'unitDiscountPrice': unitDiscountPrice,
    'reservedAt': AppData.ts(reservedAt),
    'status': status.code,
    'cancelledAt': AppData.ts(cancelledAt),
    'pickedUpAt': AppData.ts(pickedUpAt),
    'expiredAt': AppData.ts(expiredAt),
    'cancelReason': cancelReason?.code,
    'pickupReminded': pickupReminded,
  };
}
