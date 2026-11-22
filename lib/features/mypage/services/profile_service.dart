import 'package:flutter/foundation.dart';

import 'package:mp_agency/features/auth/models/app_user.dart';
import 'package:mp_agency/features/auth/services/auth_service.dart';
import 'package:mp_agency/features/sync/services/data_sync.dart';

/// 프로필 수정 실패
class ProfileException implements Exception {
  const ProfileException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// 로그인한 사용자 프로필 (기능명세 MY-001 프로필 관리)
///
/// 닉네임을 바꾸면 [current]가 바뀌어 화면들이 바로 따라 바뀜.
/// Firebase에 연결되지 않은 미리보기에서는 앱 안에서만 바뀜.
class ProfileService {
  ProfileService._();
  static final instance = ProfileService._();

  final current = ValueNotifier<AppUser?>(null);

  /// 메인 화면이 열릴 때 로그인 사용자 등록
  void start(AppUser user) {
    if (current.value?.uid != user.uid) current.value = user;
  }

  /// 닉네임 2~12자
  static String? validateNickname(String? v) {
    final t = v?.trim() ?? '';
    if (t.length < 2) return '닉네임은 2자 이상이에요';
    if (t.length > 12) return '닉네임은 12자 이하예요';
    return null;
  }

  Future<void> updateNickname(String nickname) async {
    final user = current.value;
    if (user == null) return;
    final err = validateNickname(nickname);
    if (err != null) throw ProfileException(err);
    try {
      await AuthService.instance.updateNickname(user.uid, nickname.trim());
    } catch (e) {
      // 미리보기(Firebase 미연결)에서는 앱 안에서만 바꿈
      debugPrint('닉네임 서버 저장 실패: $e');
    }
    current.value = user.copyWith(nickname: nickname.trim());
  }

  /// 회원 탈퇴 (users.status = WITHDRAWN, deleted_at 기록)
  Future<void> withdraw() async {
    final user = current.value;
    if (user == null) return;
    try {
      await AuthService.instance.withdraw(user.uid);
    } catch (e) {
      debugPrint('탈퇴 서버 처리 실패: $e');
      throw const ProfileException('탈퇴를 처리하지 못했어요. 잠시 후 다시 시도해 주세요.');
    }
    DataSync.instance.stop();
    current.value = user.copyWith(status: 'WITHDRAWN');
  }
}
