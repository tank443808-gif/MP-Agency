# MP-Agency · 다먹음

2-C반 1팀 다먹음 저장소

> **버려지기 전에, 다 먹음.**
> 판매 마감이 가까운 남은 음식을 할인 예약·픽업으로 연결해 음식 폐기를 줄이는 구매자·판매자용 모바일 앱

## 주요 기능

**구매자**: 마감 임박 상품 홈(검색·카테고리·가격 범위·거리 필터, AI 맞춤 추천) · 내 주변 지도 · 상품 상세 · 예약(테스트 결제)·픽업 번호 · 예약 내역·취소/환불 · 수령 완료 · 나의 다먹음(다먹음 지수·등급) · 찜 · 알림 · 프로필·알림 설정

**판매자**: 대시보드(회수 매출·폐기 감소율) · 상품 등록(사진·픽업 시간)·수정·판매 종료 · 예약 관리(픽업 번호로 수령 확인) · 내 가게(영업 상태·매장 정보)

## 개발 환경

| 구분 | 기술 |
| --- | --- |
| Front-end | Flutter 3.47 · Dart 3.13 |
| Back-end / DB | Firebase Authentication · Cloud Firestore · Security Rules |
| 지도·위치 | flutter_map(OpenStreetMap) · geolocator |
| 기타 | google_fonts · image_picker · url_launcher · http |

## 실행 방법

```bash
flutter pub get
flutter run -d chrome                                   # 실제 앱 (로그인 → Firestore)
flutter run -d chrome -t lib/dev/home_preview.dart      # 구매자 화면 미리보기 (로그인 없이)
flutter run -d chrome -t lib/dev/seller_preview.dart    # 판매자 화면 미리보기 (로그인 없이)
```

테스트

```bash
flutter analyze
flutter test        # 규칙 테스트 + 화면 넘침 테스트
```

Firestore 보안 규칙 배포

```bash
firebase deploy --only firestore:rules --project mp-agency
```

## 폴더 구조

```text
lib/
├── main.dart · app.dart
├── core/          공통 (테마·글꼴·로고·Firestore 도우미)
├── features/      기능별 폴더 (screens · widgets · models · services)
│   ├── auth · home · nearby · product · store · reservation
│   ├── mypage · favorite · notification · recommendation
│   └── seller_dashboard · location · navigation · sync
└── dev/           로그인 없이 화면을 띄워 보는 미리보기 진입점
```

자세한 구조·계산 규칙·환불 규칙은 [docs/README.md](docs/README.md)를 참고하세요.
