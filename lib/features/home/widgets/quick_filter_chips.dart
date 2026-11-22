import 'package:flutter/material.dart';

import 'package:mp_agency/core/theme/app_theme.dart';
import 'package:mp_agency/core/utils/formatters.dart';
import 'package:mp_agency/core/widgets/pill_chip.dart';

/// 가격 범위 (원). [max]가 [PriceRange.ceiling]이면 "그 이상 모두".
class PriceRange {
  const PriceRange(this.min, this.max);

  final int min;
  final int max;

  /// 슬라이더 최댓값 (이 값이면 상한 없음)
  static const ceiling = 10000;
  static const step = 500;

  bool contains(int price) => price >= min && (max >= ceiling || price <= max);

  /// 0원 ~ 상한 없음 = 가격 제한 없음
  bool get isAll => min == 0 && max >= ceiling;

  String get label {
    if (isAll) return '전체 가격';
    if (min == 0) return '${formatWon(max)} 이하';
    if (max >= ceiling) return '${formatWon(min)} 이상';
    return '${formatWon(min)}~${formatWon(max)}';
  }
}

/// 홈 빠른 필터 (기능명세 SRCH-003 가격 필터, 마감 임박, 위치)
class QuickFilters {
  const QuickFilters({this.price, this.closingSoon = false, this.near = false});

  /// 가격 범위 (null이면 전체)
  final PriceRange? price;

  /// 1시간 안에 마감
  final bool closingSoon;

  /// 500m 이내
  final bool near;

  static const nearMeters = 500;

  bool get any => price != null || closingSoon || near;

  QuickFilters copyWith({
    PriceRange? price,
    bool clearPrice = false,
    bool? closingSoon,
    bool? near,
  }) => QuickFilters(
    price: clearPrice ? null : (price ?? this.price),
    closingSoon: closingSoon ?? this.closingSoon,
    near: near ?? this.near,
  );
}

class QuickFilterChips extends StatelessWidget {
  const QuickFilterChips({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final QuickFilters value;
  final ValueChanged<QuickFilters> onChanged;

  Future<void> _openPrice(BuildContext context) async {
    final result = await showModalBottomSheet<_PriceResult>(
      context: context,
      backgroundColor: AppColors.cream,
      showDragHandle: true,
      builder: (_) => _PriceSheet(initial: value.price),
    );
    if (result == null) return;
    onChanged(
      result.range == null
          ? value.copyWith(clearPrice: true)
          : value.copyWith(price: result.range),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, IconData icon, bool on, VoidCallback onTap) =>
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: PillChip(
            label: label,
            icon: icon,
            selected: on,
            filled: false,
            onTap: onTap,
          ),
        );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip(
            value.price?.label ?? '가격',
            Icons.savings_outlined,
            value.price != null,
            () => _openPrice(context),
          ),
          chip(
            '1시간 안에 마감',
            Icons.local_fire_department_outlined,
            value.closingSoon,
            () => onChanged(value.copyWith(closingSoon: !value.closingSoon)),
          ),
          chip(
            '500m 이내',
            Icons.place_outlined,
            value.near,
            () => onChanged(value.copyWith(near: !value.near)),
          ),
        ],
      ),
    );
  }
}

/// 시트 결과 (range가 null이면 가격 필터 해제)
class _PriceResult {
  const _PriceResult(this.range);
  final PriceRange? range;
}

/// 가격 범위 고르기: 빠른 선택 + 슬라이더
class _PriceSheet extends StatefulWidget {
  const _PriceSheet({this.initial});

  final PriceRange? initial;

  @override
  State<_PriceSheet> createState() => _PriceSheetState();
}

class _PriceSheetState extends State<_PriceSheet> {
  late RangeValues _values = RangeValues(
    (widget.initial?.min ?? 0).toDouble(),
    (widget.initial?.max ?? PriceRange.ceiling).toDouble(),
  );

  static const _presets = [
    PriceRange(0, 2000),
    PriceRange(0, 3000),
    PriceRange(0, 5000),
    PriceRange(5000, PriceRange.ceiling),
  ];

  PriceRange get _range =>
      PriceRange(_values.start.round(), _values.end.round());

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('얼마까지 괜찮아요?', style: AppFonts.display(size: 22)),
            const SizedBox(height: 4),
            Text(
              _range.label,
              style: AppFonts.display(size: 16, color: AppColors.urgent),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in _presets)
                  PillChip(
                    label: p.label,
                    selected: p.min == _range.min && p.max == _range.max,
                    filled: false,
                    onTap: () => setState(
                      () => _values = RangeValues(
                        p.min.toDouble(),
                        p.max.toDouble(),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            RangeSlider(
              values: _values,
              min: 0,
              max: PriceRange.ceiling.toDouble(),
              divisions: PriceRange.ceiling ~/ PriceRange.step,
              activeColor: AppColors.orange,
              inactiveColor: AppColors.peach,
              labels: RangeLabels(
                formatWon(_values.start.round()),
                _values.end >= PriceRange.ceiling
                    ? '상한 없음'
                    : formatWon(_values.end.round()),
              ),
              onChanged: (v) => setState(() => _values = v),
            ),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('0원', style: TextStyle(fontSize: 12)),
                Text('10,000원 이상', style: TextStyle(fontSize: 12)),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              // 전체 범위면 필터 해제
              onPressed: () => Navigator.pop(
                context,
                _PriceResult(_range.isAll ? null : _range),
              ),
              child: Text(
                _range.isAll ? '전체 가격 음식 보기' : '${_range.label} 음식 보기',
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, const _PriceResult(null)),
              style: TextButton.styleFrom(foregroundColor: AppColors.subText),
              child: const Text('가격 상관없어요'),
            ),
          ],
        ),
      ),
    );
  }
}
