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

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  LocalStorageService? _storage;

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
    // 입력값 저장
    final input = ref.read(pensionInputProvider);
    await _storage?.saveInput(input);

    // 계산 횟수 증가
    await _storage?.incrementCalculationCount();

    // 인터스티셜 광고 표시 (3회마다)
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
                        '55세 미만 해지 시 연금소득세가 아닌\n기타소득세 16.5%가 적용됩니다',
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
