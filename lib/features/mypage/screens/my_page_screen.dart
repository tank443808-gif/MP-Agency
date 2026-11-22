import 'package:flutter/material.dart';

import 'package:mp_agency/core/theme/app_theme.dart';
import 'package:mp_agency/core/utils/formatters.dart';
import 'package:mp_agency/features/auth/models/app_user.dart';
import 'package:mp_agency/features/auth/screens/auth_gate.dart';
import 'package:mp_agency/features/favorite/screens/favorite_list_screen.dart';
import 'package:mp_agency/features/mypage/models/damukeum_stats.dart';
import 'package:mp_agency/features/mypage/screens/profile_screen.dart';
import 'package:mp_agency/features/mypage/services/profile_service.dart';
import 'package:mp_agency/features/notification/screens/notification_screen.dart';
import 'package:mp_agency/features/reservation/models/reservation.dart';
import 'package:mp_agency/features/reservation/services/reservation_service.dart';

/// 나의 다먹음 탭 (기능명세 ECO-004 개인 통계, ECO-005 지수, ECO-006 등급, MY-001)
class MyPageScreen extends StatelessWidget {
  const MyPageScreen({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    // 닉네임을 바꾸면 바로 반영
    return ValueListenableBuilder<AppUser?>(
      valueListenable: ProfileService.instance.current,
      builder: (context, current, _) =>
          _build(context, current?.uid == user.uid ? current! : user),
    );
  }

  Widget _build(BuildContext context, AppUser user) {
    return SafeArea(
      child: StreamBuilder<List<Reservation>>(
        stream: ReservationService.instance.watchMine(user.uid),
        builder: (context, snap) {
          final now = DateTime.now();
          final stats = DamukeumStats.from(snap.data ?? const [], now);
          final history = (snap.data ?? const <Reservation>[])
              .where((r) => r.displayStatus(now) == ReservationStatus.pickedUp)
              .toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Text('나의 다먹음', style: AppFonts.display(size: 26)),
              const SizedBox(height: 14),
              _ProfileRow(user: user, stats: stats),
              const SizedBox(height: 16),
              _ScoreCard(stats: stats),
              const SizedBox(height: 20),
              Text('차곡차곡, 나의 좋은 한 끼', style: AppFonts.display(size: 18)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      emoji: '🍞',
                      value: '${stats.rescuedCount}개',
                      label: '내가 살린 음식',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatTile(
                      emoji: '💰',
                      value: formatWon(stats.savedAmount),
                      label: '절약한 금액',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatTile(
                      emoji: '🌱',
                      value: '${stats.pickupCount}건',
                      label: '폐기 방지',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _GradeLadder(current: stats.grade),
              const SizedBox(height: 20),
              if (history.isNotEmpty) ...[
                Text('다먹음 기록', style: AppFonts.display(size: 18)),
                const SizedBox(height: 8),
                for (final r in history.take(5)) _HistoryRow(reservation: r),
                const SizedBox(height: 16),
              ],
              _MenuTile(
                icon: Icons.person_outline_rounded,
                label: '프로필·알림 설정',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                ),
              ),
              _MenuTile(
                icon: Icons.favorite_border_rounded,
                label: '나의 찜 목록',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => FavoriteListScreen(userId: user.uid),
                  ),
                ),
              ),
              _MenuTile(
                icon: Icons.notifications_none_rounded,
                label: '알림',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => NotificationScreen(userId: user.uid),
                  ),
                ),
              ),
              _MenuTile(
                icon: Icons.logout_rounded,
                label: '로그아웃',
                onTap: () => logout(context),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.user, required this.stats});

  final AppUser user;
  final DamukeumStats stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Color(0xFFFFEDE2),
            shape: BoxShape.circle,
          ),
          child: Text(stats.grade.emoji, style: const TextStyle(fontSize: 26)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '잘 먹는 ${user.nickname}님!',
                style: AppFonts.display(size: 18),
              ),
              Text(
                stats.pickupCount == 0
                    ? '첫 다먹음을 기다리고 있어요.'
                    : '오늘도 환경을 지키는 한 끼 고마워요.',
                style: const TextStyle(fontSize: 12, color: AppColors.subText),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 진한 초록 카드: 다먹음 지수 + 등급 + 다음 등급까지
class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.stats});

  final DamukeumStats stats;

  @override
  Widget build(BuildContext context) {
    final next = stats.grade.next;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2F4A1A),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '다먹음 지수',
                style: AppFonts.display(size: 14, color: AppColors.lightGreen),
              ),
              const Spacer(),
              const Icon(
                Icons.emoji_events_outlined,
                color: AppColors.lightGreen,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${stats.score}',
                style: AppFonts.display(size: 48, color: Colors.white),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8, left: 4),
                child: Text(
                  '점 · ${stats.grade.emoji} ${stats.grade.label}',
                  style: AppFonts.display(size: 16, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: stats.progressToNext,
              minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              color: AppColors.green,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            next == null
                ? '최고 등급이에요! 다먹음 마스터 🏆'
                : '${next.emoji} ${next.label}까지 ${stats.pointsToNext}점 남았어요',
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
          const SizedBox(height: 4),
          const Text(
            '수령 횟수 · 절약 금액 · 폐기 방지 · 제시간 수령으로 계산해요',
            style: TextStyle(fontSize: 11, color: Colors.white54),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.emoji,
    required this.value,
    required this.label,
  });

  final String emoji;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 4),
          FittedBox(child: Text(value, style: AppFonts.display(size: 17))),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.subText),
          ),
        ],
      ),
    );
  }
}

/// 🌱 새싹 → 🍀 알뜰러 → 🌳 다먹러 → 🏆 다먹음 마스터
class _GradeLadder extends StatelessWidget {
  const _GradeLadder({required this.current});

  final DamukeumGrade current;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.paleGreen,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          for (final g in DamukeumGrade.values) ...[
            Expanded(
              child: Opacity(
                opacity: g.index <= current.index ? 1 : 0.4,
                child: Column(
                  children: [
                    Text(g.emoji, style: const TextStyle(fontSize: 24)),
                    const SizedBox(height: 2),
                    Text(
                      g.label,
                      textAlign: TextAlign.center,
                      style: AppFonts.display(
                        size: 11,
                        color: g == current
                            ? AppColors.deepGreen
                            : AppColors.text,
                      ),
                    ),
                    Text(
                      '${g.minScore}점~',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.subText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (g != DamukeumGrade.values.last)
              const Icon(
                Icons.chevron_right,
                size: 16,
                color: AppColors.subText,
              ),
          ],
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.reservation});

  final Reservation reservation;

  @override
  Widget build(BuildContext context) {
    final r = reservation;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(r.product.displayEmoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${r.product.name} ${r.quantity}개 · ${r.product.storeName}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Text(
            '+${formatWon(r.savedAmount)}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.deepGreen,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: Color(0xFFFFEDE2),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppColors.urgent, size: 20),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.subText),
      onTap: onTap,
    );
  }
}
