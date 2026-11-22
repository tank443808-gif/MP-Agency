import 'package:cloud_firestore/cloud_firestore.dart';

/// 사용자 역할: 음식을 사는 구매자 / 음식을 파는 사업자
enum UserRole {
  customer('CUSTOMER', '구매자'),
  seller('SELLER', '사업자');

  const UserRole(this.code, this.label);

  /// Firestore에 저장되는 값
  final String code;

  /// 화면에 보여줄 이름
  final String label;

  static UserRole fromCode(String? code) => UserRole.values.firstWhere(
    (r) => r.code == code,
    orElse: () => UserRole.customer,
  );
}

/// Firestore `users/{uid}` 문서
class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    required this.nickname,
    required this.role,
    this.storeName,
    this.status = 'ACTIVE',
  });

  final String uid;
  final String email;
  final String nickname;
  final UserRole role;

  /// 사업자만 사용 (매장명)
  final String? storeName;

  /// 계정 상태 (users.status): ACTIVE · WITHDRAWN
  final String status;

  bool get isWithdrawn => status == 'WITHDRAWN';

  AppUser copyWith({String? nickname, String? status}) => AppUser(
    uid: uid,
    email: email,
    nickname: nickname ?? this.nickname,
    role: role,
    storeName: storeName,
    status: status ?? this.status,
  );

  bool get isSeller => role == UserRole.seller;

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return AppUser(
      uid: doc.id,
      email: data['email'] as String? ?? '',
      nickname: data['nickname'] as String? ?? '',
      role: UserRole.fromCode(data['role'] as String?),
      storeName: data['storeName'] as String?,
      status: data['status'] as String? ?? 'ACTIVE',
    );
  }

  Map<String, dynamic> toMap() => {
    'email': email,
    'nickname': nickname,
    'role': role.code,
    'status': status,
    if (storeName != null) 'storeName': storeName,
  };
}
