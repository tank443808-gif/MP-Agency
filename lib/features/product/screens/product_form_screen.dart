import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'package:mp_agency/core/theme/app_theme.dart';
import 'package:mp_agency/core/utils/formatters.dart';
import 'package:mp_agency/core/widgets/pill_chip.dart';
import 'package:mp_agency/features/product/models/product.dart';
import 'package:mp_agency/features/product/services/product_service.dart';
import 'package:mp_agency/features/store/models/store.dart';

/// 상품 등록·수정 (기능명세 SELL-003, SELL-004)
/// "오늘 남은 맛, 누군가의 한 끼로."
class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({
    super.key,
    required this.store,
    this.product,
    this.copyFrom,
  });

  final Store store;

  /// 수정할 상품 (없으면 새로 등록)
  final Product? product;

  /// 이 상품 내용을 채워서 새로 등록 (다시 등록하기)
  final Product? copyFrom;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  static const _emojis = [
    '🥐',
    '🍞',
    '🥖',
    '🍩',
    '🧁',
    '🍰',
    '🥪',
    '🍙',
    '🍱',
    '🍳',
    '🍜',
    '🥗',
    '🍕',
    '🍔',
    '☕',
    '🧃',
  ];

  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: _source?.name);
  late final _original = TextEditingController(
    text: _source?.originalPrice.toString(),
  );
  late final _discount = TextEditingController(
    text: _source?.discountPrice.toString(),
  );
  late final _stock = TextEditingController(
    text: (widget.product?.stockQuantity ?? _source?.totalStock ?? 1)
        .toString(),
  );
  late final _description = TextEditingController(text: _source?.description);

  late ProductCategory _category = _source?.category ?? widget.store.category;
  late String _emoji = _source?.displayEmoji ?? _category.emoji;
  late DateTime _saleEndAt =
      widget.product?.saleEndAt.isAfter(DateTime.now()) == true
      ? widget.product!.saleEndAt
      : _defaultEnd();

  /// 픽업 시작 (null이면 예약 즉시)
  late DateTime? _pickupStart = _isEdit ? widget.product!.pickupStartAt : null;

  /// 픽업 종료 (기본: 판매 종료 30분 뒤)
  late DateTime _pickupEnd =
      (_isEdit ? widget.product!.pickupEndAt : null) ??
      _saleEndAt.add(const Duration(minutes: 30));

  /// 올린 사진
  late Uint8List? _photo = _source?.imageBytes;
  bool _saving = false;

  Product? get _source => widget.product ?? widget.copyFrom;
  bool get _isEdit => widget.product != null;

  static DateTime _defaultEnd() {
    final t = DateTime.now().add(const Duration(hours: 2));
    return DateTime(t.year, t.month, t.day, t.hour, t.minute - t.minute % 10);
  }

  @override
  void dispose() {
    for (final c in [_name, _original, _discount, _stock, _description]) {
      c.dispose();
    }
    super.dispose();
  }

  int? get _discountRate {
    final o = int.tryParse(_original.text);
    final d = int.tryParse(_discount.text);
    if (o == null || d == null || o <= 0 || d >= o) return null;
    return ((o - d) * 100 / o).round();
  }

  /// 시:분을 골라 가장 가까운 앞으로의 시각으로 돌려줌 (지난 시각이면 내일)
  Future<DateTime?> _pickClock(DateTime initial, String help) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      helpText: help,
    );
    if (picked == null) return null;
    final now = DateTime.now();
    var t = DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
    if (!t.isAfter(now)) t = t.add(const Duration(days: 1));
    return t;
  }

  Future<void> _pickSaleEnd() async {
    final t = await _pickClock(_saleEndAt, '판매 종료 시간');
    if (t == null) return;
    setState(() {
      _saleEndAt = t;
      // 픽업 종료는 판매 종료 이후여야 함
      if (_pickupEnd.isBefore(t)) {
        _pickupEnd = t.add(const Duration(minutes: 30));
      }
    });
  }

  Future<void> _pickPickupStart() async {
    final t = await _pickClock(_pickupStart ?? DateTime.now(), '픽업 시작 시간');
    if (t != null) setState(() => _pickupStart = t);
  }

  Future<void> _pickPickupEnd() async {
    final t = await _pickClock(_pickupEnd, '픽업 종료 시간');
    if (t != null) setState(() => _pickupEnd = t);
  }

  /// 상품 사진 고르기 (SELL-003)
  Future<void> _pickPhoto() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        // 상품 문서 안에 저장하므로 작게 줄임 (Firestore 문서 한도 1MB)
        maxWidth: 640,
        maxHeight: 640,
        imageQuality: 60,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (mounted) setState(() => _photo = bytes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('사진을 불러오지 못했어요.')));
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final name = _name.text.trim();
    final original = int.parse(_original.text);
    final discount = int.parse(_discount.text);
    final stock = int.parse(_stock.text);
    final desc = _description.text.trim().isEmpty
        ? null
        : _description.text.trim();
    try {
      if (_isEdit) {
        ProductService.instance.update(
          widget.product!.copyWith(
            name: name,
            category: _category,
            emoji: _emoji,
            originalPrice: original,
            discountPrice: discount,
            stockQuantity: stock,
            saleEndAt: _saleEndAt,
            description: desc,
            imageBytes: _photo,
            clearImage: _photo == null,
            pickupStartAt: _pickupStart,
            pickupEndAt: _pickupEnd,
          ),
        );
      } else {
        ProductService.instance.add(
          store: widget.store,
          name: name,
          category: _category,
          emoji: _emoji,
          originalPrice: original,
          discountPrice: discount,
          stock: stock,
          saleEndAt: _saleEndAt,
          description: desc,
          imageBytes: _photo,
          pickupStartAt: _pickupStart,
          pickupEndAt: _pickupEnd,
        );
      }
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEdit ? '상품을 수정했어요.' : '등록 완료! 누군가의 한 끼가 될 거예요.'),
        ),
      );
    } on StockException catch (e) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  String? _requiredNumber(String? v, {int min = 0}) {
    final n = int.tryParse(v ?? '');
    if (n == null) return '숫자를 입력해 주세요';
    if (n < min) return '$min 이상이어야 해요';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final rate = _discountRate;
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? '상품 수정' : '상품 등록')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            if (!_isEdit) ...[
              Text(
                '오늘 남은 맛,\n누군가의 한 끼로.',
                style: AppFonts.display(size: 26, height: 1.3),
              ),
              const SizedBox(height: 4),
              const Text(
                '남은 음식을 등록하면 근처 손님에게 바로 보여요.',
                style: TextStyle(fontSize: 13, color: AppColors.subText),
              ),
              const SizedBox(height: 18),
            ],
            const _Label('상품 사진'),
            _PhotoBox(
              photo: _photo,
              onPick: _pickPhoto,
              onRemove: () => setState(() => _photo = null),
            ),
            const SizedBox(height: 18),
            Text(
              _photo == null ? '사진이 없으면 보여줄 그림' : '사진을 못 불러올 때 보여줄 그림',
              style: AppFonts.display(size: 14),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in _emojis)
                  GestureDetector(
                    onTap: () => setState(() => _emoji = e),
                    child: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: e == _emoji ? _category.color : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: e == _emoji
                              ? AppColors.orange
                              : AppColors.border,
                          width: e == _emoji ? 2 : 1,
                        ),
                      ),
                      child: Text(e, style: const TextStyle(fontSize: 22)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            const _Label('상품명'),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(hintText: '예: 버터 크루아상'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '상품명을 입력해 주세요' : null,
            ),
            const SizedBox(height: 18),
            const _Label('카테고리'),
            // 화면이 좁으면 다음 줄로 넘어가도록 Wrap 사용
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in ProductCategory.values)
                  PillChip(
                    label: c.label,
                    selected: c == _category,
                    filled: false,
                    onTap: () => setState(() => _category = c),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Label('정가'),
                      _NumberField(
                        controller: _original,
                        suffix: '원',
                        onChanged: (_) => setState(() {}),
                        validator: (v) => _requiredNumber(v, min: 1),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Label('할인가'),
                      _NumberField(
                        controller: _discount,
                        suffix: '원',
                        onChanged: (_) => setState(() {}),
                        validator: (v) {
                          final err = _requiredNumber(v);
                          if (err != null) return err;
                          final o = int.tryParse(_original.text) ?? 0;
                          if (int.parse(v!) >= o) return '정가보다 낮게';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (rate != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '🔥 $rate% 할인 · 손님은 '
                  '${formatWon(int.parse(_original.text) - int.parse(_discount.text))} 아껴요',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.urgent,
                  ),
                ),
              ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Label(_isEdit ? '남은 수량' : '수량'),
                      _NumberField(
                        controller: _stock,
                        suffix: '개',
                        validator: (v) =>
                            _requiredNumber(v, min: _isEdit ? 0 : 1),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Label('판매 종료'),
                      InkWell(
                        onTap: _pickSaleEnd,
                        borderRadius: BorderRadius.circular(14),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            suffixIcon: Icon(Icons.schedule),
                          ),
                          child: Text(
                            formatClock(_saleEndAt),
                            style: const TextStyle(fontSize: 15),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const _Label('픽업 시간'),
            Row(
              children: [
                Expanded(
                  child: _TimeField(
                    text: _pickupStart == null
                        ? '예약 즉시'
                        : formatClock(_pickupStart!),
                    onTap: _pickPickupStart,
                    onClear: _pickupStart == null
                        ? null
                        : () => setState(() => _pickupStart = null),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('~'),
                ),
                Expanded(
                  child: _TimeField(
                    text: formatClock(_pickupEnd),
                    onTap: _pickPickupEnd,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              '손님은 이 시간 안에 받아가야 해요. 픽업 종료는 판매 종료 이후로 정해 주세요.',
              style: TextStyle(fontSize: 12, color: AppColors.subText),
            ),
            const SizedBox(height: 18),
            const _Label('상품 설명 (선택)'),
            TextFormField(
              controller: _description,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: '예: 오늘 아침 구운 빵이에요. 오늘 안에 드시면 가장 맛있어요.',
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.paleGreen,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                '픽업 장소: ${widget.store.name} · ${widget.store.address}\n'
                '픽업 시간: ${formatTimeRange(_pickupStart, _pickupEnd)}',
                style: const TextStyle(fontSize: 12, height: 1.5),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_isEdit ? '수정 완료' : '등록하기'),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: AppFonts.display(size: 14)),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.suffix,
    this.validator,
    this.onChanged,
  });

  final TextEditingController controller;
  final String suffix;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(suffixText: suffix),
      validator: validator,
      onChanged: onChanged,
    );
  }
}

/// 상품 사진 상자: 없으면 [사진 추가], 있으면 미리보기 + 삭제
class _PhotoBox extends StatelessWidget {
  const _PhotoBox({
    required this.photo,
    required this.onPick,
    required this.onRemove,
  });

  final Uint8List? photo;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: onPick,
          child: Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: photo == null
                ? const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_a_photo_outlined,
                        color: AppColors.urgent,
                        size: 28,
                      ),
                      SizedBox(height: 4),
                      Text('사진 추가', style: TextStyle(fontSize: 12)),
                    ],
                  )
                : Image.memory(photo!, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: photo == null
              ? const Text(
                  '실제 음식 사진을 올리면 손님이 더 믿고 예약해요.',
                  style: TextStyle(fontSize: 12, color: AppColors.subText),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextButton.icon(
                      onPressed: onPick,
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: const Text('사진 바꾸기'),
                    ),
                    TextButton.icon(
                      onPressed: onRemove,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.subText,
                      ),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('사진 지우기'),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// 누르면 시간 선택이 열리는 칸
class _TimeField extends StatelessWidget {
  const _TimeField({required this.text, required this.onTap, this.onClear});

  final String text;
  final VoidCallback onTap;

  /// 값을 비우기 (픽업 시작 → 예약 즉시)
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(
          suffixIcon: onClear == null
              ? const Icon(Icons.schedule)
              : IconButton(
                  tooltip: '예약 즉시로',
                  onPressed: onClear,
                  icon: const Icon(Icons.close, size: 18),
                ),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14),
        ),
      ),
    );
  }
}
