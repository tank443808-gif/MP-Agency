import 'package:flutter/material.dart';

import 'package:mp_agency/core/theme/app_theme.dart';
import 'package:mp_agency/core/utils/formatters.dart';
import 'package:mp_agency/features/product/models/product.dart';
import 'package:mp_agency/features/product/widgets/product_card.dart';

/// 예약 전 확인 시트: "이거 버리기 아까운데… 다먹음?"
/// [다먹음!]을 누르면 true를 돌려줌.
Future<bool> showReserveConfirmSheet(
  BuildContext context, {
  required Product product,
  required int quantity,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: AppColors.cream,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _ReserveConfirmSheet(product: product, quantity: quantity),
  );
  return result ?? false;
}

class _ReserveConfirmSheet extends StatelessWidget {
  const _ReserveConfirmSheet({required this.product, required this.quantity});

  final Product product;
  final int quantity;

  @override
  Widget build(BuildContext context) {
    final p = product;
    final total = p.discountPrice * quantity;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '이거 버리기 아까운데…\n다먹음?',
              textAlign: TextAlign.center,
              style: AppFonts.display(size: 24, height: 1.3),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  ProductThumbnail(product: p, size: 56),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.storeName,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.subText,
                          ),
                        ),
                        Text(
                          '${p.name} · $quantity개',
                          style: AppFonts.display(size: 16),
                        ),
                        Text(
                          '${formatTimeRange(p.pickupStartAt, p.pickupDeadline)} 픽업',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.urgent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(formatWon(total), style: AppFonts.display(size: 18)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: AppColors.subText,
                ),
                SizedBox(width: 4),
                Text(
                  '지금은 테스트 결제예요. 실제로 돈이 나가지 않아요.',
                  style: TextStyle(fontSize: 12, color: AppColors.subText),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('다먹음! ${formatWon(total)} 예약하기'),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              style: TextButton.styleFrom(foregroundColor: AppColors.subText),
              child: const Text('조금 더 둘러볼게요'),
            ),
          ],
        ),
      ),
    );
  }
}
