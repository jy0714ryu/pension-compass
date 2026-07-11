import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/pension_provider.dart';
import '../services/local_storage_service.dart';
import '../services/nps_estimator.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/input_widgets.dart';

/// 국민연금 미니 계산기 — 단독 화면 (인증·네트워크 0, 온디바이스 즉시 계산).
///
/// exec-plan "① 국민연금 간이 계산" + "UI 투트랙 ②" 구현. 홈 화면 상단 배너 또는
/// 5번째 카드 링크에서 진입한다. "이 값으로 인출 설계까지 해보기" 버튼(auto-fill)을
/// 누르면 [PensionInputProvider]에 국민연금 값을 채우고 저장한 뒤 `pop(true)`로
/// 돌아간다 — 호출부(`HomeScreen`)가 그 결과로 5번째 카드를 펼친다.
class NpsCalculatorScreen extends ConsumerStatefulWidget {
  final LocalStorageService? storage;

  const NpsCalculatorScreen({super.key, this.storage});

  @override
  ConsumerState<NpsCalculatorScreen> createState() =>
      _NpsCalculatorScreenState();
}

class _NpsCalculatorScreenState extends ConsumerState<NpsCalculatorScreen> {
  LocalStorageService? _storage;

  int _monthlyIncome = 0; // 원
  int _enrollmentYears = 20; // 년 (내부에서 ×12 하여 개월로 변환)
  int _birthYear = 1975;
  NpsReceiptType _receiptType = NpsReceiptType.normal;

  /// 정확값 우회로(넛지) — true 면 공단 조회값을 직접 입력받는다.
  bool _directInputMode = false;
  int _directAmount = 0; // 원

  @override
  void initState() {
    super.initState();
    _storage = widget.storage;
    if (_storage == null) {
      LocalStorageService.create().then((s) {
        if (mounted) setState(() => _storage = s);
      });
    }
  }

  bool get _inputsComplete =>
      _monthlyIncome > 0 && _enrollmentYears > 0 && _birthYear > 1900;

  NpsEstimateResult? _resultFor(NpsReceiptType type) {
    if (!_inputsComplete) return null;
    return NpsEstimator.estimate(
      NpsEstimateInput(
        monthlyIncome: _monthlyIncome,
        enrollmentMonths: _enrollmentYears * 12,
        birthYear: _birthYear,
        receiptType: type,
        offsetYears: type == NpsReceiptType.normal ? 0 : 5,
      ),
    );
  }

  NpsEstimateResult? get _earlyResult => _resultFor(NpsReceiptType.early);
  NpsEstimateResult? get _normalResult => _resultFor(NpsReceiptType.normal);
  NpsEstimateResult? get _deferredResult =>
      _resultFor(NpsReceiptType.deferred);

  NpsEstimateResult? get _selectedResult {
    switch (_receiptType) {
      case NpsReceiptType.early:
        return _earlyResult;
      case NpsReceiptType.normal:
        return _normalResult;
      case NpsReceiptType.deferred:
        return _deferredResult;
    }
  }

  Future<void> _onAutoFill() async {
    final result = _selectedResult;
    if (result == null || !result.isEligible) return;

    final amount = _directInputMode && _directAmount > 0
        ? _directAmount
        : result.monthlyPensionAmount;

    ref.read(pensionInputProvider.notifier).setNps(amount, result.actualStartAge);

    final updatedInput = ref.read(pensionInputProvider);
    await _storage?.saveInput(updatedInput);

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat('#,###');
    final result = _selectedResult;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('국민연금 계산기'),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InputSectionCard(
              title: '기본 정보',
              icon: Icons.info_outline,
              children: [
                AmountInputField(
                  label: '월소득',
                  value: _monthlyIncome,
                  onChanged: (v) => setState(() => _monthlyIncome = v),
                  helperText: '가입기간 중 평균 월소득 (세전)',
                ),
                const SizedBox(height: 16),
                PlainNumberInputField(
                  label: '가입기간',
                  value: _enrollmentYears,
                  suffix: '년',
                  onChanged: (v) => setState(() => _enrollmentYears = v),
                  helperText: '예: 20년 가입 시 20 입력',
                ),
                const SizedBox(height: 16),
                PlainNumberInputField(
                  label: '출생연도',
                  value: _birthYear,
                  suffix: '년',
                  onChanged: (v) => setState(() => _birthYear = v),
                  helperText: '예: 1975',
                ),
              ],
            ),
            const SizedBox(height: 16),

            Text('수령 방식', style: AppTextStyles.label),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _ReceiptTypeButton(
                    label: '조기수령\n(-30%, 5년조기)',
                    selected: _receiptType == NpsReceiptType.early,
                    onTap: () =>
                        setState(() => _receiptType = NpsReceiptType.early),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ReceiptTypeButton(
                    label: '정상수령',
                    selected: _receiptType == NpsReceiptType.normal,
                    onTap: () =>
                        setState(() => _receiptType = NpsReceiptType.normal),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ReceiptTypeButton(
                    label: '연기수령\n(+36%, 5년연기)',
                    selected: _receiptType == NpsReceiptType.deferred,
                    onTap: () => setState(
                        () => _receiptType = NpsReceiptType.deferred),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            if (result == null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.gray200),
                ),
                child: Text(
                  '월소득·가입기간·출생연도를 입력하면\n예상수령액이 바로 계산됩니다',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body,
                ),
              )
            else if (!result.isEligible)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                ),
                child: const Text(
                  '가입기간이 10년(120개월) 미만이라\n노령연금을 받을 수 없습니다',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.warning, height: 1.5),
                ),
              )
            else
              Container(
                width: double.infinity,
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
                    Text('월 예상수령액', style: AppTextStyles.label),
                    const SizedBox(height: 8),
                    if (!_directInputMode)
                      Text(
                        '${formatter.format(result.monthlyPensionAmount)}원',
                        style: AppTextStyles.numberLarge,
                      )
                    else
                      AmountInputField(
                        label: '',
                        value: _directAmount,
                        onChanged: (v) => setState(() => _directAmount = v),
                        hint: '공단 조회값 입력',
                      ),
                    const SizedBox(height: 4),
                    TextButton.icon(
                      onPressed: () =>
                          setState(() => _directInputMode = !_directInputMode),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        alignment: Alignment.centerLeft,
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: Icon(
                        _directInputMode ? Icons.undo : Icons.edit,
                        size: 16,
                      ),
                      label: Text(
                        _directInputMode
                            ? '간이 추정값으로 되돌리기'
                            : '간이 추정입니다 — 공단 조회값 직접 입력 ✏️',
                        style: AppTextStyles.caption,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '수급 개시연령: ${result.actualStartAge}세',
                      style: AppTextStyles.body,
                    ),
                    const SizedBox(height: 20),
                    Text('조기 / 정상 / 연기 비교', style: AppTextStyles.label),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _CompareTile(
                            label: '조기',
                            amount: _earlyResult?.monthlyPensionAmount,
                            formatter: formatter,
                            highlighted: _receiptType == NpsReceiptType.early,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _CompareTile(
                            label: '정상',
                            amount: _normalResult?.monthlyPensionAmount,
                            formatter: formatter,
                            highlighted: _receiptType == NpsReceiptType.normal,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _CompareTile(
                            label: '연기',
                            amount: _deferredResult?.monthlyPensionAmount,
                            formatter: formatter,
                            highlighted:
                                _receiptType == NpsReceiptType.deferred,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    PrimaryButton(
                      text: '이 값으로 인출 설계까지 해보기 →',
                      onPressed: _onAutoFill,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),

            Text(
              '간이 추정치입니다. 정확한 금액은 국민연금공단 조회 기준.',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: const SafeArea(
        child: BannerAdWidget(),
      ),
    );
  }
}

class _ReceiptTypeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ReceiptTypeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.navy : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.navy : AppColors.gray200,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTextStyles.caption.copyWith(
            color: selected ? Colors.white : AppColors.gray700,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _CompareTile extends StatelessWidget {
  final String label;
  final int? amount;
  final NumberFormat formatter;
  final bool highlighted;

  const _CompareTile({
    required this.label,
    required this.amount,
    required this.formatter,
    required this.highlighted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: highlighted ? AppColors.navy.withValues(alpha: 0.08) : AppColors.gray50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: highlighted ? AppColors.navy : AppColors.gray200,
        ),
      ),
      child: Column(
        children: [
          Text(label, style: AppTextStyles.labelSmall),
          const SizedBox(height: 4),
          Text(
            amount != null ? '${formatter.format(amount)}원' : '-',
            style: AppTextStyles.numberSmall.copyWith(fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
