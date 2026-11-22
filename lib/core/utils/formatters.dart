// 가격·시간 표시용 공용 함수

/// 1500 → "1,500원"
String formatWon(int price) {
  final digits = price.toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return '$buf원';
}

/// 남은 시간 → "48분 남음", "1시간 12분 남음", "판매 종료"
String formatRemaining(Duration d) {
  if (d.inSeconds <= 0) return '판매 종료';
  final h = d.inHours;
  final m = d.inMinutes % 60;
  if (h == 0) return '${m == 0 ? 1 : m}분 남음';
  if (m == 0) return '$h시간 남음';
  return '$h시간 $m분 남음';
}

/// 350 → "350m", 1200 → "1.2km"
String formatDistance(int meters) =>
    meters < 1000 ? '${meters}m' : '${(meters / 1000).toStringAsFixed(1)}km';

/// 시각 → "18:30", 내일이면 "내일 09:00"
String formatClock(DateTime t, {DateTime? now}) {
  final base = now ?? DateTime.now();
  final hh = t.hour.toString().padLeft(2, '0');
  final mm = t.minute.toString().padLeft(2, '0');
  final today = DateTime(base.year, base.month, base.day);
  final day = DateTime(t.year, t.month, t.day);
  final diff = day.difference(today).inDays;
  final prefix = diff == 0
      ? '오늘 '
      : (diff == 1 ? '내일 ' : '${t.month}/${t.day} ');
  return '$prefix$hh:$mm';
}

/// 픽업 시간 → "오늘 18:00 ~ 19:30" (시작이 없으면 "오늘 19:30까지")
String formatTimeRange(DateTime? start, DateTime end, {DateTime? now}) {
  if (start == null) return '${formatClock(end, now: now)}까지';
  final e = formatClock(end, now: now);
  final sameDay =
      start.year == end.year &&
      start.month == end.month &&
      start.day == end.day;
  // 같은 날이면 끝 시각은 "19:30"만
  return '${formatClock(start, now: now)} ~ ${sameDay ? e.split(' ').last : e}';
}
