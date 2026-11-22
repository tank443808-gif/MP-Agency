import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'package:mp_agency/app.dart';
import 'package:mp_agency/core/data/app_data.dart';
import 'package:mp_agency/firebase_options.dart';

/// 앱 시작점: Firebase 초기화 → Firestore 저장 모드 → 앱 실행
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // 실제 앱은 Firestore에 저장 (미리보기·테스트는 메모리)
  AppData.useFirestore = true;
  runApp(const MyApp());
}
