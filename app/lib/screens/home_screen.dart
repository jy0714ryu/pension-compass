import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';

import '../providers/pension_provider.dart';
import '../widgets/input_widgets.dart';
import '../widgets/disclaimer_dialog.dart';
import '../widgets/banner_ad_widget.dart';
import '../services/local_storage_service.dart';
import '../services/ad_service.dart';
import 'result_screen.dart';
import 'nps_calculator_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  LocalStorageService? _storage;

  /// 국민연금 5번째 카드 펼침 상태 — 기본 접힘 (기존 사용자 마찰 0).
  /// 미니 계산기 auto-fill 로 돌아올 때만 true 로 강제 전환된다.
  bool _npsCardExpanded = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // 로컬 스토리지 초기화
    _storage = await LocalStorageService.create();

    // 저장된 입력값 불러오기
    final savedInput = _storage!.loadInput();
    if (savedInput != null) {
      ref.read(pensionInputProvider.notifier).loadFromStorage(savedInput);
      // 저장된 국민연금 값이 있으면(과거 auto-fill 이력) 카드를 펼쳐서 보여준다.
      if (savedInput.hasNps && mounted) {
        setState(() => _npsCardExpanded = true);
      }
    }

    // 면책조항 동의 확인
    if (!_storage!.isDisclaimerAccepted()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showDisclaimerDialog();
      });
    }
  }

  void _showDisclaimerDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => DisclaimerDialog(
        onAccept: () async {
          await _storage?.setDisclaimerAccepted(true);
          if (!context.mounted) return;
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _onCalculate() async {
    final input = ref.read(pensionInputProvider);

    // 국민연금 부분 입력(월수령액·개시연령 중 하나만) 경고 — hasNps AND 게이트라
    // 시뮬레이션에는 어차피 미반영되지만, 사용자가 값을 넣고도 반영 안 됐다고
    // 오해하지 않도록 안내한다.
    final npsPartiallyFilled =
        (input.npsMonthlyAmount != null) != (input.npsStartAge != null);
    if (npsPartiallyFilled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('국민연금은 수령액·개시연령을 모두 입력해야 반영됩니다'),
        ),
      );
    }

    // 입력값 저장
    await _storage?.saveInput(input);

    // 계산 횟수 증가
    await _storage?.incrementCalculationCount();

    // 인터스티셜 광고 표시 (2회마다, 첫 계산 면제)
    await AdService().showInterstitialIfEligible();

    // 결과 화면으로 이동
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResultScreen(storage: _storage),
      ),
    );
  }

  /// 국민연금 미니 계산기 화면 진입 — auto-fill 로 돌아오면 5번째 카드를 펼친다.
  Future<void> _openNpsCalculator() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => NpsCalculatorScreen(storage: _storage),
      ),
    );
    if (result == true && mounted) {
      setState(() => _npsCardExpanded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final input = ref.watch(pensionInputProvider);
    final canSimulate = ref.watch(canSimulateProvider);
    final totalAssets = ref.watch(totalAssetsProvider);
    final formatter = NumberFormat('#,###');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('연금나침반'),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () {
              ref.read(pensionInputProvider.notifier).loadExample();
            },
            child: const Text(
              '예시 입력',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.navy, AppColors.navyLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.explore, color: Colors.white, size: 28),
                      SizedBox(width: 8),
                      Text(
                        '최적 인출 순서 찾기',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '같은 금액을 인출해도, 순서만 바꾸면\n세금이 수백만 원 달라집니다',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  if (totalAssets > 0) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '총 자산: ${formatter.format(totalAssets ~/ 10000)}만원',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 국민연금 미니 계산기 진입 배너
            InkWell(
              onTap: _openNpsCalculator,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: AppColors.info.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.calculate_outlined, color: AppColors.info),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '국민연금 예상수령액 계산',
                        style: TextStyle(
                          color: AppColors.info,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right, color: AppColors.info),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 연금저축 입력
            InputSectionCard(
              title: '연금저축',
              icon: Icons.savings,
              children: [
                AmountInputField(
                  label: '연금저축 잔액',
                  value: input.pensionSavings,
                  onChanged: (v) => ref
                      .read(pensionInputProvider.notifier)
                      .updatePensionSavings(v),
                ),
                const SizedBox(height: 16),
                AmountInputField(
                  label: '세액공제 받은 금액',
                  value: input.pensionSavingsDeducted,
                  onChanged: (v) => ref
                      .read(pensionInputProvider.notifier)
                      .updatePensionSavingsDeducted(v),
                  helperText: '대부분 전액이면 그대로 두세요',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // IRP 입력
            InputSectionCard(
              title: 'IRP',
              icon: Icons.account_balance,
              children: [
                AmountInputField(
                  label: 'IRP 잔액',
                  value: input.irpBalance,
                  onChanged: (v) => ref
                      .read(pensionInputProvider.notifier)
                      .updateIrpBalance(v),
                ),
                const SizedBox(height: 16),
                AmountInputField(
                  label: '퇴직금 이전분',
                  value: input.irpRetirementPortion,
                  onChanged: (v) => ref
                      .read(pensionInputProvider.notifier)
                      .updateIrpRetirementPortion(v),
                  helperText: '퇴직금 받아서 IRP로 넣은 금액',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ISA 입력
            InputSectionCard(
              title: 'ISA',
              icon: Icons.account_balance_wallet,
              children: [
                AmountInputField(
                  label: 'ISA 만기 예정액',
                  value: input.isaMaturity,
                  onChanged: (v) => ref
                      .read(pensionInputProvider.notifier)
                      .updateIsaMaturity(v),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 기본 정보
            InputSectionCard(
              title: '기본 정보',
              icon: Icons.person,
              children: [
                NumberInputField(
                  label: '현재 나이',
                  value: input.currentAge,
                  suffix: '세',
                  min: 20,
                  max: 100,
                  onChanged: (v) => ref
                      .read(pensionInputProvider.notifier)
                      .updateCurrentAge(v),
                ),
                const SizedBox(height: 16),
                AmountInputField(
                  label: '연간 목표 인출액',
                  value: input.targetAnnualWithdrawal,
                  onChanged: (v) => ref
                      .read(pensionInputProvider.notifier)
                      .updateTargetAnnualWithdrawal(v),
                ),
                const SizedBox(height: 16),
                NumberInputField(
                  label: '예상 연 수익률 (복리)',
                  value: (input.expectedReturnRate * 100).round(),
                  suffix: '%',
                  min: 0,
                  max: 15,
                  onChanged: (v) => ref
                      .read(pensionInputProvider.notifier)
                      .updateExpectedReturnRate(v / 100.0),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 국민연금 (선택) — 5번째 접이식 카드, 기본 접힘 (기존 사용자 마찰 0)
            CollapsibleInputSectionCard(
              title: '국민연금 (선택)',
              icon: Icons.payments_outlined,
              badgeText: '선택',
              expanded: _npsCardExpanded,
              onExpansionChanged: (v) {
                setState(() => _npsCardExpanded = v);
                if (!v) {
                  // 접으면 값도 함께 리셋 — 미입력 상태와 완전히 동일하게 복원
                  // (기존 4장 폼 동작에 영향 없음이 이 리셋으로 보장됨).
                  ref.read(pensionInputProvider.notifier).clearNps();
                }
              },
              children: [
                AmountInputField(
                  label: '월 예상수령액',
                  value: input.npsMonthlyAmount ?? 0,
                  onChanged: (v) => ref
                      .read(pensionInputProvider.notifier)
                      .updateNpsMonthlyAmount(v),
                ),
                const SizedBox(height: 16),
                NumberInputField(
                  label: '수급 개시연령',
                  value: input.npsStartAge ?? 65,
                  suffix: '세',
                  min: 50,
                  max: 100,
                  onChanged: (v) => ref
                      .read(pensionInputProvider.notifier)
                      .updateNpsStartAge(v),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _openNpsCalculator,
                    icon: const Icon(Icons.calculate_outlined, size: 18),
                    label: const Text('간이 계산기로 추정하기'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 시뮬레이션 버튼
            PrimaryButton(
              text: '🔍 최적화 시뮬레이션',
              onPressed: canSimulate ? _onCalculate : null,
            ),
            const SizedBox(height: 8),
            if (!canSimulate)
              const Center(
                child: Text(
                  '자산 정보를 입력해주세요',
                  style: TextStyle(
                    color: AppColors.gray500,
                    fontSize: 14,
                  ),
                ),
              ),
            const SizedBox(height: 32),

            // 55세 미만 경고
            if (input.currentAge < 55)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.warning.withOpacity(0.3),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber, color: AppColors.warning),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '연금계좌 인출은 55세부터 가능해\n55세까지는 적립·운용만 하고,\n인출은 55세부터 시뮬레이션합니다',
                        style: TextStyle(
                          color: AppColors.warning,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 80), // 하단 여백
          ],
        ),
      ),
      bottomNavigationBar: const SafeArea(
        child: BannerAdWidget(),
      ),
    );
  }
}
