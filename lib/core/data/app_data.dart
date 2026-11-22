import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// 데이터 저장 방식 설정 + Firestore 공통 도우미
///
/// - 실제 앱(main.dart): [useFirestore] = true → Firestore에 저장
/// - 미리보기(lib/dev)·테스트: false → 앱 메모리에만 저장
///
/// 각 서비스는 Firestore를 실시간 구독해 앱 안에 사본을 들고 있고,
/// 화면은 그 사본을 읽습니다. 저장은 사본을 먼저 바꾸고 Firestore에 씁니다.
class AppData {
  AppData._();

  static bool useFirestore = false;

  static FirebaseFirestore get db => FirebaseFirestore.instance;

  /// Firestore에 쓰기. 메모리 모드면 아무것도 안 함.
  /// 실패하면 로그만 남김 (실시간 구독이 서버 상태로 되돌려 줌).
  static void write(String what, Future<void> Function() op) {
    if (!useFirestore) return;
    op().catchError((Object e) {
      debugPrint('Firestore $what 실패: $e');
    });
  }

  static DateTime? date(Object? v) => v is Timestamp ? v.toDate() : null;

  static Timestamp? ts(DateTime? d) => d == null ? null : Timestamp.fromDate(d);

  static int toInt(Object? v, [int fallback = 0]) =>
      v is num ? v.toInt() : fallback;

  static double toDouble(Object? v, [double fallback = 0]) =>
      v is num ? v.toDouble() : fallback;
}
