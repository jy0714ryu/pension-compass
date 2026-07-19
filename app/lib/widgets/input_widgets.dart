import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// 금액 입력 필드
class AmountInputField extends StatefulWidget {
  final String label;
  final String? hint;
  final int value;
  final ValueChanged<int> onChanged;
  final String suffix;
  final bool enabled;
  final String? helperText;

  const AmountInputField({
    super.key,
    required this.label,
    this.hint,
    required this.value,
    required this.onChanged,
    this.suffix = '만원',
    this.enabled = true,
    this.helperText,
  });

  @override
  State<AmountInputField> createState() => _AmountInputFieldState();
}

class _AmountInputFieldState extends State<AmountInputField> {
  late TextEditingController _controller;
  final _formatter = NumberFormat('#,###');

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.value > 0 ? _formatter.format(widget.value ~/ 10000) : '',
    );
  }

  @override
  void didUpdateWidget(AmountInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 표시 텍스트의 파싱값과 외부 state 를 비교해 불일치 시에만 재작성한다.
    // 문자열 contains 비교는 state=0(newText='')일 때 contains('')가 항상 true 라
    // 리셋·clamp 가 화면에 반영되지 않는 버그가 있었다 (v1.1.1 감사 C1):
    // 화면엔 이전 금액이 남고 계산은 0으로 수행 → 세금 과소 표시.
    // 사용자 타이핑 중에는 파싱값 == state 라 재작성이 일어나지 않아 커서가 유지된다.
    final clean = _controller.text.replaceAll(',', '');
    final displayedValue = (int.tryParse(clean) ?? 0) * 10000;
    if (displayedValue == widget.value) return;
    final newText =
        widget.value > 0 ? _formatter.format(widget.value ~/ 10000) : '';
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: AppTextStyles.label),
        const SizedBox(height: 8),
        TextField(
          controller: _controller,
          enabled: widget.enabled,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            _ThousandsSeparatorFormatter(),
          ],
          decoration: InputDecoration(
            hintText: widget.hint ?? '0',
            suffixText: widget.suffix,
            filled: true,
            fillColor: widget.enabled ? Colors.white : AppColors.gray100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.gray200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.gray200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.navy, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          style: AppTextStyles.bodyLarge.copyWith(
            color: AppColors.gray800,
          ),
          onChanged: (text) {
            final cleanText = text.replaceAll(',', '');
            final value = int.tryParse(cleanText) ?? 0;
            widget.onChanged(value * 10000); // 만원 단위 → 원 단위
          },
        ),
        if (widget.helperText != null) ...[
          const SizedBox(height: 4),
          Text(
            widget.helperText!,
            style: AppTextStyles.caption.copyWith(color: AppColors.gray500),
          ),
        ],
      ],
    );
  }
}

class _ThousandsSeparatorFormatter extends TextInputFormatter {
  final _formatter = NumberFormat('#,###');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    final cleanText = newValue.text.replaceAll(',', '');
    final value = int.tryParse(cleanText);
    
    if (value == null) {
      return oldValue;
    }

    final formatted = _formatter.format(value);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// 숫자 입력 필드 (나이 등)
class NumberInputField extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final String suffix;
  final int min;
  final int max;

  const NumberInputField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.suffix = '',
    this.min = 0,
    this.max = 100,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton(
              onPressed: value > min
                  ? () => onChanged(value - 1)
                  : null,
              icon: const Icon(Icons.remove_circle_outline),
              color: AppColors.navy,
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.gray200),
                ),
                child: Text(
                  '$value$suffix',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.h4,
                ),
              ),
            ),
            IconButton(
              onPressed: value < max
                  ? () => onChanged(value + 1)
                  : null,
              icon: const Icon(Icons.add_circle_outline),
              color: AppColors.navy,
            ),
          ],
        ),
      ],
    );
  }
}

/// 입력 섹션 카드
class InputSectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const InputSectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.gray200.withOpacity(0.5),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.navy, size: 24),
              const SizedBox(width: 8),
              Text(title, style: AppTextStyles.h4),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }
}

/// 접이식 입력 섹션 카드 (국민연금 5번째 카드 전용 — 기본 접힘 UX)
///
/// [InputSectionCard]와 동일한 시각 스타일을 유지하되, 헤더를 탭하면
/// [expanded] 상태를 부모에게 알려 펼침/접힘을 전환한다. 펼침 상태는 부모
/// (`HomeScreen`)가 소유한다 — auto-fill 등으로 외부에서 강제로 펼치기 위함.
class CollapsibleInputSectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool expanded;
  final ValueChanged<bool> onExpansionChanged;
  final String? badgeText;
  final List<Widget> children;

  const CollapsibleInputSectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.expanded,
    required this.onExpansionChanged,
    required this.children,
    this.badgeText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.gray200.withValues(alpha: 0.5),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => onExpansionChanged(!expanded),
            child: Row(
              children: [
                Icon(icon, color: AppColors.navy, size: 24),
                const SizedBox(width: 8),
                Text(title, style: AppTextStyles.h4),
                if (badgeText != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.gray100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      badgeText!,
                      style: AppTextStyles.labelSmall,
                    ),
                  ),
                ],
                const Spacer(),
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  color: AppColors.gray500,
                ),
              ],
            ),
          ),
          if (expanded) ...[
            const SizedBox(height: 20),
            ...children,
          ],
        ],
      ),
    );
  }
}

/// 단위 변환 없는 순수 숫자 입력 필드 (가입기간·출생연도 등)
///
/// [AmountInputField]와 달리 입력값을 그대로(×10000 하지 않고) 전달한다.
class PlainNumberInputField extends StatefulWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final String suffix;
  final String? helperText;

  const PlainNumberInputField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.suffix = '',
    this.helperText,
  });

  @override
  State<PlainNumberInputField> createState() => _PlainNumberInputFieldState();
}

class _PlainNumberInputFieldState extends State<PlainNumberInputField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.value > 0 ? widget.value.toString() : '',
    );
  }

  @override
  void didUpdateWidget(PlainNumberInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newText = widget.value > 0 ? widget.value.toString() : '';
    if (_controller.text != newText) {
      _controller.text = newText;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: AppTextStyles.label),
        const SizedBox(height: 8),
        TextField(
          controller: _controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            hintText: '0',
            suffixText: widget.suffix,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.gray200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.gray200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.navy, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          style: AppTextStyles.bodyLarge.copyWith(color: AppColors.gray800),
          onChanged: (text) {
            final value = int.tryParse(text) ?? 0;
            widget.onChanged(value);
          },
        ),
        if (widget.helperText != null) ...[
          const SizedBox(height: 4),
          Text(
            widget.helperText!,
            style: AppTextStyles.caption.copyWith(color: AppColors.gray500),
          ),
        ],
      ],
    );
  }
}

/// 주요 버튼
class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;

  const PrimaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.green,
          disabledBackgroundColor: AppColors.gray300,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(text, style: AppTextStyles.button),
      ),
    );
  }
}
