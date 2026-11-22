import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:mp_agency/features/auth/models/app_user.dart';

/// Firebase Authentication(계정) + Firestore `users` 컬렉션(프로필·역할)을 묶은 서비스
class AuthService {
  AuthService._();
  static final instance = AuthService._();

  final _auth = FirebaseAuth.instance;
  final _users = FirebaseFirestore.instance.collection('users');

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<AppUser?> fetchProfile(String uid) async {
    final doc = await _users.doc(uid).get();
    return doc.exists ? AppUser.fromDoc(doc) : null;
  }

  /// 회원가입: Auth 계정 생성 후 Firestore에 역할 정보 저장
  Future<AppUser> signUp({
    required String email,
    required String password,
    required String nickname,
    required UserRole role,
    String? storeName,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = cred.user!.uid;
    final user = AppUser(
      uid: uid,
      email: email,
      nickname: nickname,
      role: role,
      storeName: role == UserRole.seller ? storeName : null,
    );
    try {
      await _users.doc(uid).set({
        ...user.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // 프로필 저장 실패 시 반쪽짜리 계정이 남지 않도록 정리
      await cred.user!.delete();
      rethrow;
    }
    return user;
  }

  /// 로그인: 선택한 역할과 DB에 저장된 역할이 다르면 로그아웃 후 예외
  Future<AppUser> signIn({
    required String email,
    required String password,
    required UserRole expectedRole,
  }) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final profile = await fetchProfile(cred.user!.uid);
    if (profile == null) {
      await _auth.signOut();
      throw const AuthFailure('회원 정보가 없습니다. 다시 가입해 주세요.');
    }
    if (profile.isWithdrawn) {
      await _auth.signOut();
      throw const AuthFailure('탈퇴한 계정이에요. 새로 가입해 주세요.');
    }
    if (profile.role != expectedRole) {
      await _auth.signOut();
      throw AuthFailure(
        '${profile.role.label} 계정입니다. 상단에서 "${profile.role.label}"를 선택해 주세요.',
      );
    }
    return profile;
  }

  /// 닉네임 수정 (MY-001). updatedAt 함께 갱신.
  Future<void> updateNickname(String uid, String nickname) =>
      _users.doc(uid).update({
        'nickname': nickname,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  /// 회원 탈퇴: 기록은 남기고 상태만 바꿈 (users.status, deleted_at) 후 로그아웃
  Future<void> withdraw(String uid) async {
    await _users.doc(uid).update({
      'status': 'WITHDRAWN',
      'deletedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _auth.signOut();
  }

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email);

  Future<void> signOut() => _auth.signOut();
}

class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Firebase 오류 코드를 한국어 메시지로 변환
String authErrorMessage(Object e) {
  if (e is AuthFailure) return e.message;
  if (e is FirebaseAuthException) {
    switch (e.code) {
      case 'invalid-email':
        return '이메일 형식이 올바르지 않습니다.';
      case 'user-disabled':
        return '사용이 중지된 계정입니다.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return '이메일 또는 비밀번호가 올바르지 않습니다.';
      case 'email-already-in-use':
        return '이미 가입된 이메일입니다.';
      case 'weak-password':
        return '비밀번호는 6자 이상이어야 합니다.';
      case 'too-many-requests':
        return '시도가 너무 많습니다. 잠시 후 다시 시도해 주세요.';
      case 'network-request-failed':
        return '네트워크 연결을 확인해 주세요.';
      case 'operation-not-allowed':
        return 'Firebase 콘솔에서 이메일/비밀번호 로그인을 활성화해 주세요.';
      case 'configuration-not-found':
        return 'Firebase Authentication이 아직 시작되지 않았습니다. 콘솔에서 Authentication → 시작하기를 눌러 주세요.';
    }
    if ((e.message ?? '').contains('CONFIGURATION_NOT_FOUND')) {
      return 'Firebase Authentication이 아직 시작되지 않았습니다. 콘솔에서 Authentication → 시작하기를 눌러 주세요.';
    }
    return e.message ?? '인증 오류가 발생했습니다. (${e.code})';
  }
  if (e is FirebaseException && e.code == 'permission-denied') {
    return 'DB 접근 권한이 없습니다. Firestore 보안 규칙을 확인해 주세요.';
  }
  return '오류가 발생했습니다: $e';
}
