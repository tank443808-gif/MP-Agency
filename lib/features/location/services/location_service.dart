import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import 'package:mp_agency/features/location/models/user_location.dart';

/// GPS 현재 위치 + 주소(동네 이름) 변환
class LocationService {
  LocationService._();
  static final instance = LocationService._();

  /// 위치를 못 가져올 때 쓰는 기본 위치 (신구대학교 부근)
  static const fallbackLatitude = 37.4486;
  static const fallbackLongitude = 127.1679;
  static const fallbackLabel = '성남시 · 신구대';

  /// 직접 고를 수 있는 지역 (기능명세 SRCH-005 "선택 지역")
  static const presetAreas = [
    UserLocation(
      latitude: 37.4486,
      longitude: 127.1679,
      label: '성남시 · 신구대학교',
      status: LocationStatus.selected,
    ),
    UserLocation(
      latitude: 37.4515,
      longitude: 127.1597,
      label: '성남시 · 남한산성입구역',
      status: LocationStatus.selected,
    ),
    UserLocation(
      latitude: 37.4321,
      longitude: 127.1290,
      label: '성남시 · 모란역',
      status: LocationStatus.selected,
    ),
    UserLocation(
      latitude: 37.4113,
      longitude: 127.1286,
      label: '성남시 · 야탑역',
      status: LocationStatus.selected,
    ),
    UserLocation(
      latitude: 37.3851,
      longitude: 127.1232,
      label: '성남시 · 서현역',
      status: LocationStatus.selected,
    ),
  ];

  /// 지금 쓰는 위치 (홈·내 주변이 같이 씀). 바뀌면 화면들이 따라 바뀜.
  final location = ValueNotifier<UserLocation?>(null);
  Future<UserLocation>? _pending;

  UserLocation? get last => location.value;

  /// 저장된 위치가 있으면 그것을, 없으면 GPS로 새로 가져옴
  Future<UserLocation> current({bool refresh = false}) {
    if (!refresh && last != null) return Future.value(last);
    return _pending ??= getCurrentLocation().then((loc) {
      location.value = loc;
      _pending = null;
      return loc;
    });
  }

  /// 지역 직접 선택
  void select(UserLocation area) => location.value = area;

  /// 현재 위치를 가져옴. 실패하면 기본 위치와 실패 이유를 돌려줌.
  Future<UserLocation> getCurrentLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return _fallback(LocationStatus.serviceDisabled);
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return _fallback(LocationStatus.denied);
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      final label = await _addressLabel(pos.latitude, pos.longitude);
      return UserLocation(
        latitude: pos.latitude,
        longitude: pos.longitude,
        label: label ?? '현재 위치',
        status: LocationStatus.current,
      );
    } catch (e) {
      debugPrint('위치 가져오기 실패: $e');
      return _fallback(LocationStatus.error);
    }
  }

  /// 두 지점 사이 거리 (미터)
  int distanceMeters(double lat1, double lng1, double lat2, double lng2) =>
      Geolocator.distanceBetween(lat1, lng1, lat2, lng2).round();

  /// 기기 설정 화면 열기 (권한을 영구 거부했을 때 등)
  Future<void> openSettings(LocationStatus status) async {
    if (kIsWeb) return; // 웹은 브라우저 주소창의 위치 권한에서 변경
    if (status == LocationStatus.serviceDisabled) {
      await Geolocator.openLocationSettings();
    } else {
      await Geolocator.openAppSettings();
    }
  }

  UserLocation _fallback(LocationStatus status) => UserLocation(
    latitude: fallbackLatitude,
    longitude: fallbackLongitude,
    label: fallbackLabel,
    status: status,
  );

  /// 위도·경도 → "시 · 동" 형태 이름.
  ///
  /// OpenStreetMap Nominatim(무료) 사용. 이용 정책상 초당 1회 이하로만 호출해야 하며,
  /// 실제 서비스 출시 때는 카카오 로컬 API 등으로 바꾸는 것을 권장.
  Future<String?> _addressLabel(double lat, double lng) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'format': 'jsonv2',
        'lat': '$lat',
        'lon': '$lng',
        'zoom': '16',
        'accept-language': 'ko',
      });
      final res = await http
          .get(uri, headers: kIsWeb ? null : {'User-Agent': 'damukeum-app'})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;

      final address =
          (jsonDecode(res.body) as Map<String, dynamic>)['address']
              as Map<String, dynamic>?;
      if (address == null) return null;

      String? pick(List<String> keys) {
        for (final k in keys) {
          final v = address[k];
          if (v is String && v.isNotEmpty) return v;
        }
        return null;
      }

      final city = pick(['city', 'county', 'province', 'state']);
      final area = pick([
        'quarter',
        'suburb',
        'neighbourhood',
        'borough',
        'town',
        'village',
      ]);
      if (city == null && area == null) return null;
      if (city == null || area == null) return city ?? area;
      return '$city · $area';
    } catch (e) {
      debugPrint('주소 변환 실패: $e');
      return null;
    }
  }
}
