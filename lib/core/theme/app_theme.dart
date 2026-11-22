import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 다먹음 브랜드 컬러 (기획서: 오렌지 + 연두 + 크림색)
class AppColors {
  static const orange = Color(0xFFFF8A3D);
  static const green = Color(0xFF8BC34A);
  static const cream = Color(0xFFFFF8EC);
  static const text = Color(0xFF3B2F2A);
  static const subText = Color(0xFF8A7B72);
  static const border = Color(0xFFEFE3D3);

  /// 홈 배너 등 연한 연두 배경
  static const lightGreen = Color(0xFFDDEFB8);

  /// 안내 박스 배경
  static const paleGreen = Color(0xFFEFF6E1);

  /// 마감 임박(1시간 이내) 강조
  static const urgent = Color(0xFFE8533A);

  /// 진한 연두 (배너 글씨, 성공 표시)
  static const deepGreen = Color(0xFF4E7A1E);

  /// 연한 오렌지 배경 (뱃지, 썸네일)
  static const peach = Color(0xFFFFE7D3);

  /// 그림자 색
  static const shadow = Color(0x14A0602A);
}

/// 다먹음 글꼴
///
/// - 로고·제목·가격: 「주아(Jua)」 — 동글동글하고 먹음직스러운 느낌
/// - 본문: 「고운돋움(Gowun Dodum)」 — 부드럽고 읽기 편한 느낌
class AppFonts {
  /// 고운돋움·주아에 없는 글자(예: 뿍, 놨)를 대신 그려줄 글꼴
  static final List<String> fallback = [GoogleFonts.notoSansKr().fontFamily!];

  /// 제목·숫자용 (Jua)
  static TextStyle display({
    double size = 18,
    Color color = AppColors.text,
    double? height,
  }) => GoogleFonts.jua(
    fontSize: size,
    color: color,
    height: height,
  ).copyWith(fontFamilyFallback: fallback);
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.orange,
    primary: AppColors.orange,
    secondary: AppColors.green,
    surface: Colors.white,
  );
  final radius = BorderRadius.circular(14);

  return ThemeData(
    colorScheme: scheme,
    // 본문 기본 글꼴: 고운돋움
    fontFamily: GoogleFonts.gowunDodum().fontFamily,
    fontFamilyFallback: AppFonts.fallback,
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.text,
      contentTextStyle: GoogleFonts.gowunDodum(
        fontSize: 14,
        color: Colors.white,
      ),
      shape: RoundedRectangleBorder(borderRadius: radius),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: AppColors.orange, width: 1.6),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.orange,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: GoogleFonts.jua(fontSize: 17),
      ),
    ),
  );
}
