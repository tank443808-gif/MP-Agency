/// 위치를 가져온 결과 상태
enum LocationStatus {
  /// GPS로 현재 위치를 가져옴
  current,

  /// 위치 권한이 거부됨
  denied,

  /// 기기 위치 서비스(GPS)가 꺼져 있음
  serviceDisabled,

  /// 그 밖의 오류 (시간 초과 등)
  error,

  /// 사용자가 지역을 직접 골랐음 (기능명세 SRCH-005 선택 지역)
  selected,
}

/// 사용자 현재 위치
class UserLocation {
  const UserLocation({
    required this.latitude,
    required this.longitude,
    required this.label,
    required this.status,
  });

  final double latitude;
  final double longitude;

  /// 화면에 보여줄 이름 (예: "성남시 · 금광동")
  final String label;
  final LocationStatus status;

  /// GPS·직접 고른 지역이 아니라, 실패해서 기본 위치를 쓰는 중인지
  bool get isFallback =>
      status != LocationStatus.current && status != LocationStatus.selected;
}
