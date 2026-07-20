import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../providers/pension_provider.dart';
import '../models/pension_input.dart';
import '../models/saved_scenario.dart';
import '../models/simulation_result.dart';
import '../services/health_insurance_estimator.dart';
import '../services/local_storage_service.dart';
import '../services/monte_carlo_simulator.dart';
import '../services/in_app_review_service.dart';
import '../services/result_narrative.dart';
import '../widgets/banner_ad_widget.dart';

class ResultScreen extends ConsumerStatefulWidget {
  final LocalStorageService? storage;

  const ResultScreen({super.key, this.storage});

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  bool _reviewRequested = false;

  /// 공유 카드 이미지 캡처용 (RepaintBoundary)
  final GlobalKey _shareCardKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _requestReviewIfEligible();
  }

  Future<void> _requestReviewIfEligible() async {
    if (_reviewRequested || widget.storage == null) return;
    _reviewRequested = true;

    // 약간의 딜레이 후 리뷰 요청 (결과를 먼저 보게 함)
    await Future.delayed(const Duration(seconds: 2));

    final result = ref.read(simulationResultProvider);
    if (result != null) {
      final savings = result.savings;
      final reviewService = InAppReviewService(widget.storage!);
      await reviewService.requestReviewIfEligible(savings);
    }
  }

  /// 인출 출처별 뱃지 색상
  Color _getBadgeColor(WithdrawalSource source) {
    switch (source) {
      case WithdrawalSource.isaProfit:
      case WithdrawalSource.isaPrincipal:
      case WithdrawalSource.pensionNonDeducted:
        return AppColors.green; // 비과세 = 그린
      case WithdrawalSource.pensionDeducted:
      case WithdrawalSource.irpSelf:
      case WithdrawalSource.earnings:
        return AppColors.info; // 분리과세 = 블루
      case WithdrawalSource.irpRetirement:
        return AppColors.warning; // 퇴직소득 = 오렌지
    }
  }

  /// 세금 유형 라벨
  String _getTaxLabel(WithdrawalSource source) {
    switch (source) {
      case WithdrawalSource.isaProfit:
      case WithdrawalSource.isaPrincipal:
      case WithdrawalSource.pensionNonDeducted:
        return '비과세';
      case WithdrawalSource.pensionDeducted:
      case WithdrawalSource.irpSelf:
      case WithdrawalSource.earnings:
        return '분리과세';
      case WithdrawalSource.irpRetirement:
        return '퇴직소득';
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(simulationResultProvider);
    final input = ref.watch(pensionInputProvider);
    final formatter = NumberFormat('#,###');

    if (result == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('결과')),
        body: const Center(child: Text('시뮬레이션 결과가 없습니다')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('최적화 결과'),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // 시나리오 저장 버튼 (v1.2 — 저장 후 홈에서 2-up 비교)
          IconButton(
            icon: const Icon(Icons.bookmark_add_outlined),
            onPressed: () => _showSaveScenarioDialog(context, input),
            tooltip: '시나리오로 저장',
          ),
          // 공유 버튼
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _showShareDialog(context, result, formatter),
            tooltip: '결과 공유',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 내러티브 헤더 — "이 계획이면 월 ○○만원을 N년간 쓸 수 있습니다"
            _buildNarrativeHeader(result, input, formatter),
            const SizedBox(height: 16),

            // 한 줄 절세 요약 카드 (공유용 — RepaintBoundary로 이미지 캡처 대상)
            RepaintBoundary(
              key: _shareCardKey,
              child: _buildShareableCard(result, formatter),
            ),
            const SizedBox(height: 16),
            
            // 최적 인출 순서 카드 (색상 뱃지 적용)
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
                      Icon(Icons.emoji_events, color: Colors.amber, size: 28),
                      SizedBox(width: 8),
                      Text(
                        '최적 인출 순서',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 1,500만원 한도 안내
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.amber.withAlpha(40),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.amber, size: 16),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '연금저축/IRP는 연 1,500만원까지 분리과세 적용',
                            style: TextStyle(color: Colors.amber, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...result.optimalSequence.asMap().entries.map((entry) {
                    final index = entry.key;
                    final source = entry.value;
                    final badgeColor = _getBadgeColor(source);
                    final taxLabel = _getTaxLabel(source);
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          // 순위 번호 (색상 뱃지)
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: badgeColor,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  source.displayName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: badgeColor.withAlpha(180),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        taxLabel,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 절감 효과 카드
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.gray200.withAlpha(128),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.savings, color: AppColors.green, size: 24),
                      const SizedBox(width: 8),
                      const Text('절감 효과', style: AppTextStyles.h4),
                      const Spacer(),
                      // 기존 방식 설명 아이콘
                      GestureDetector(
                        onTap: () => _showBaselineExplanation(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.gray100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 16,
                                color: AppColors.gray500,
                              ),
                              SizedBox(width: 4),
                              Text(
                                '비교 기준?',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.gray500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTaxCard(
                          label: '기존 방식',
                          amount: result.totalTaxBaseline,
                          color: AppColors.gray500,
                          formatter: formatter,
                          subtitle: '연금저축부터 인출',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTaxCard(
                          label: '최적 방식',
                          amount: result.totalTaxOptimal,
                          color: AppColors.navy,
                          formatter: formatter,
                          subtitle: result.optimalStrategyName,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.green.withAlpha(26),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.arrow_downward,
                          color: AppColors.green,
                          size: 28,
                        ),
                        const SizedBox(width: 8),
                        // 좁은 기기(360dp)에서 4자리 절감액이 오버플로되지 않게 축소
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '${formatter.format(result.savings ~/ 10000)}만원 절감',
                              style: const TextStyle(
                                color: AppColors.green,
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.green,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '-${result.savingsRate.toStringAsFixed(1)}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 전략 비교표 (4전략 토너먼트 전체 결과)
            _buildStrategyComparisonCard(result, formatter),
            const SizedBox(height: 20),

            // 몬테카를로 성공 확률 (v1.3 — 1,000경로, isolate 계산)
            _buildMonteCarloCard(formatter),
            const SizedBox(height: 20),

            // 건강보험료 카드 (국민연금 입력 시에만)
            if (input.hasNps) ...[
              _buildHealthInsuranceCard(input),
              const SizedBox(height: 20),
            ],

            // 차트
            Container(
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
                  const Row(
                    children: [
                      Icon(Icons.show_chart, color: AppColors.navy, size: 24),
                      SizedBox(width: 8),
                      Text('연도별 누적 세금', style: AppTextStyles.h4),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildLegend(AppColors.chartOptimal, '최적 방식'),
                      const SizedBox(width: 16),
                      _buildLegend(AppColors.chartBaseline, '기존 방식'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 200,
                    child: _buildChart(result),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 연도별 상세
            Container(
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
                  const Row(
                    children: [
                      Icon(Icons.table_chart, color: AppColors.navy, size: 24),
                      SizedBox(width: 8),
                      Text('연도별 상세', style: AppTextStyles.h4),
                    ],
                  ),
                  if (input.hasNps) ...[
                    const SizedBox(height: 12),
                    _buildCrevasseSummaryBanner(result, input, formatter),
                  ],
                  const SizedBox(height: 16),
                  _buildDetailTable(result, input, formatter),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 전문가 팁 & 안내사항
            _buildExpertTips(hasNps: input.hasNps),
            const SizedBox(height: 24),

            // 다시 계산 버튼
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: AppColors.navy),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '🔄 다시 계산하기',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
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

  /// 결과 최상단 내러티브 헤더 — "이 계획이면 월 ○○만원을 N년간 쓸 수 있습니다"
  /// (v1.1 Task 6, exec-plan §③ "불안 → 숫자")
  Widget _buildNarrativeHeader(
    SimulationResult result,
    PensionInput input,
    NumberFormat formatter,
  ) {
    final narrative = computeWithdrawalNarrative(result, input);
    final monthlyManwon =
        formatter.format(narrative.monthlyWithdrawal ~/ 10000);

    final String headline;
    final String subline;
    if (narrative.depleted) {
      headline = '월 $monthlyManwon만원, ${narrative.depletionAge}세에 자산이 소진됩니다';
      subline = '${narrative.fundedYears}년간은 목표 인출액을 그대로 채울 수 있습니다.';
    } else {
      headline = '월 $monthlyManwon만원, ${narrative.fundedYears}년간 쓸 수 있습니다';
      subline = '시뮬레이션 기간 내내 목표 인출액에 여유가 있습니다.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            headline,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subline,
            style: TextStyle(
              color: Colors.white.withAlpha(200),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  /// 건강보험료 카드 (국민연금 입력 시에만 렌더) — v1.1 Task 6, exec-plan §②
  Widget _buildHealthInsuranceCard(PensionInput input) {
    final estimateInput = HealthInsuranceEstimateInput(
      annualPublicPensionIncome: input.npsMonthlyAmount! * 12,
    );
    final estimate = HealthInsuranceEstimator.estimate(estimateInput);
    final eligibility =
        HealthInsuranceEstimator.checkDependentEligibility(estimateInput);
    final formatter = NumberFormat('#,###');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.gray200.withAlpha(128),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.local_hospital, color: AppColors.info, size: 24),
              SizedBox(width: 8),
              Text('국민연금 개시 후 건강보험료', style: AppTextStyles.h4),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.info.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '월 예상 건강보험료(장기요양 포함) ',
                  style: TextStyle(fontSize: 13, color: AppColors.gray600),
                ),
                Text(
                  '${formatter.format(estimate.monthlyTotalPremium)}원',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.info,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildTipCard(
            icon: Icons.check_circle,
            iconColor: AppColors.green,
            title: '연금계좌 인출은 건보료에 안 잡힙니다',
            content:
                '연금계좌(연금저축·IRP) 인출은 현재 기준 건강보험료 부과 소득에 포함되지 않습니다 (제도 변경 가능성 있음).',
            backgroundColor: AppColors.green.withAlpha(20),
          ),
          if (eligibility.dependentDisqualified) ...[
            const SizedBox(height: 12),
            _buildTipCard(
              icon: Icons.warning_amber,
              iconColor: AppColors.error,
              title: '피부양자 자격 상실 기준 해당',
              content: '⚠️ 연소득 2,000만원 초과 — 피부양자 자격 상실 기준(소득 기준)에 해당합니다.',
              backgroundColor: AppColors.error.withAlpha(20),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            '재산(부동산 등) 기준분을 제외한 소득 기준 추정치입니다.',
            style: TextStyle(fontSize: 12, color: AppColors.gray500),
          ),
        ],
      ),
    );
  }

  /// 국민연금 개시 전/후 소득 크레바스 요약 배너 (연도별 상세 표 위)
  Widget _buildCrevasseSummaryBanner(
    SimulationResult result,
    PensionInput input,
    NumberFormat formatter,
  ) {
    final crevasse = computeCrevasseSummary(result, input);
    final postAmount = crevasse.postNpsAnnualWithdrawal;

    final String text;
    if (crevasse.gapYears == 0) {
      if (postAmount == null) {
        text = '국민연금이 처음부터 함께 지급됩니다.';
      } else if (postAmount == 0) {
        text = '국민연금만으로 목표 생활비가 충당됩니다.';
      } else {
        text = '국민연금이 첫해부터 반영되어 연금계좌 인출 부담이 연 '
            '${formatter.format(postAmount ~/ 10000)}만원으로 줄었습니다.';
      }
    } else if (postAmount != null) {
      text = '개시 전 공백기 ${crevasse.gapYears}년은 연금계좌에서 연 '
          '${formatter.format(crevasse.preNpsAnnualWithdrawal ~/ 10000)}만원, '
          '개시 후엔 연 ${formatter.format(postAmount ~/ 10000)}만원만 인출합니다.';
    } else {
      text = '시뮬레이션 기간 ${crevasse.gapYears}년 내내 국민연금 개시 전으로, '
          '연금계좌에서 연 ${formatter.format(crevasse.preNpsAnnualWithdrawal ~/ 10000)}만원을 인출합니다.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.navy.withAlpha(15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.timeline, color: AppColors.navy, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12.5, color: AppColors.navy, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  /// 전문가 팁 & 안내사항 위젯
  Widget _buildExpertTips({required bool hasNps}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.gray200.withAlpha(128),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb, color: AppColors.warning, size: 24),
              SizedBox(width: 8),
              Text('알아두면 좋은 팁', style: AppTextStyles.h4),
            ],
          ),
          const SizedBox(height: 16),
          
          // 1. 건강보험료 안심 문구 (가장 중요!)
          _buildTipCard(
            icon: Icons.health_and_safety,
            iconColor: AppColors.green,
            title: '건강보험료 걱정 NO!',
            content: '사적연금(연금저축/IRP) 수령액은 건강보험료 산정 소득에 포함되지 않습니다.',
            backgroundColor: AppColors.green.withAlpha(20),
          ),
          const SizedBox(height: 12),
          
          // 2. 법정 인출 순서 안내
          _buildTipCard(
            icon: Icons.account_balance,
            iconColor: AppColors.info,
            title: '계좌 분리 운영 권장',
            content: '실제 금융사에서는 계좌 내 법정 순서대로 인출됩니다. 최적 순서를 맞추려면 비과세용 계좌와 과세용 계좌를 분리해 두는 것이 유리합니다.',
            backgroundColor: AppColors.info.withAlpha(20),
          ),
          const SizedBox(height: 12),
          
          // 3. 16.5% 면책조항
          _buildTipCard(
            icon: Icons.info_outline,
            iconColor: AppColors.gray500,
            title: '계산 기준 안내',
            content: '연 1,500만원 초과 시 16.5% 분리과세를 가정한 보수적 계산 결과입니다. 실제로는 종합과세 선택이 유리할 수 있으니 세무사 상담을 권장합니다.',
            backgroundColor: AppColors.gray100,
          ),
          const SizedBox(height: 12),

          // 4. 시뮬레이션 가정 안내
          _buildTipCard(
            icon: Icons.trending_up,
            iconColor: AppColors.navy,
            title: '시뮬레이션 가정',
            content: '남은 잔액은 입력한 연 수익률로 복리 성장하며, 운용수익은 세법에 따라 과세 재원으로 편입해 계산합니다. 연금수령한도(10년 룰) 초과 인출은 16.5% 과세로 반영됩니다. 4가지 인출 전략을 전 기간 시뮬레이션해 비교한 결과입니다.',
            backgroundColor: AppColors.navy.withAlpha(15),
          ),

          // 5. 국민연금 종합과세 미반영 고지 (국민연금 입력 시에만, TAX_RULES §7.7)
          if (hasNps) ...[
            const SizedBox(height: 12),
            _buildTipCard(
              icon: Icons.receipt_long,
              iconColor: AppColors.warning,
              title: '국민연금은 세금 계산에 미반영',
              content: '국민연금은 종합과세 대상으로 이번 시뮬레이션의 세금 계산에는 반영되지 않았습니다 (현금흐름만 반영).',
              backgroundColor: AppColors.warning.withAlpha(20),
            ),
          ],
        ],
      ),
    );
  }

  /// 개별 팁 카드 위젯
  Widget _buildTipCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String content,
    required Color backgroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: iconColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.gray600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaxCard({
    required String label,
    required int amount,
    required Color color,
    required NumberFormat formatter,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(13),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(51)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: color.withAlpha(153),
                fontSize: 11,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            '${formatter.format(amount ~/ 10000)}만원',
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  /// 기존 방식 설명 다이얼로그
  void _showBaselineExplanation(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.85,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.gray300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Row(
                children: [
                  Icon(Icons.info, color: AppColors.navy, size: 24),
                  SizedBox(width: 8),
                  Text(
                    '비교 기준 설명',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.gray100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '기존 방식이란?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '대부분의 사람들이 하는 일반적인 인출 방법입니다:',
                    style: TextStyle(fontSize: 14, height: 1.5),
                  ),
                  SizedBox(height: 12),
                  _ComparisonRow(
                    order: '1',
                    text: '연금저축 공제분부터 인출',
                    isOptimal: false,
                  ),
                  _ComparisonRow(
                    order: '2',
                    text: 'IRP에서 인출',
                    isOptimal: false,
                  ),
                  _ComparisonRow(
                    order: '3',
                    text: 'ISA는 맨 나중에 (비과세 낭비)',
                    isOptimal: false,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.green.withAlpha(26),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '최적 방식은?',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.green,
                    ),
                  ),
                  SizedBox(height: 8),
                  _ComparisonRow(
                    order: '1',
                    text: 'ISA, 비공제분 먼저 (세금 0원)',
                    isOptimal: true,
                  ),
                  _ComparisonRow(
                    order: '2',
                    text: '연금저축 연 1,500만원 이하 유지',
                    isOptimal: true,
                  ),
                  _ComparisonRow(
                    order: '3',
                    text: 'IRP 퇴직금분은 마지막에',
                    isOptimal: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('확인', style: TextStyle(color: Colors.white)),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildLegend(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTextStyles.caption,
        ),
      ],
    );
  }

  Widget _buildChart(SimulationResult result) {
    final cumulativeOptimal = result.cumulativeTaxOptimal;

    // 기존 방식 누적 세금 — baseline 전략의 실제 연도별 스케줄
    final cumulativeBaseline = result.cumulativeTaxBaseline;

    // 전액 비과세 입력 등으로 누적 세금이 0(또는 스케줄이 비어있음)이면
    // maxY=0 → horizontalInterval: maxY / 4 가 0.0이 되어 fl_chart 크래시
    // (debug assert / release UnsupportedError). 최소 1.0으로 floor.
    final maxY = math.max(
        (cumulativeBaseline.isNotEmpty
                ? cumulativeBaseline.last
                : (cumulativeOptimal.isNotEmpty ? cumulativeOptimal.last : 0))
            .toDouble(),
        1.0);

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 4,
          getDrawingHorizontalLine: (value) => FlLine(
            color: AppColors.gray200,
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 45,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${(value / 10000).toStringAsFixed(0)}만',
                  style: AppTextStyles.caption,
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: (result.schedule.length / 5).ceilToDouble(),
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toInt() + 1}년',
                  style: AppTextStyles.caption,
                );
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          // 기존 방식 (회색)
          LineChartBarData(
            spots: cumulativeBaseline.asMap().entries.map((e) {
              return FlSpot(e.key.toDouble(), e.value.toDouble());
            }).toList(),
            isCurved: true,
            color: AppColors.chartBaseline,
            barWidth: 3,
            dotData: const FlDotData(show: false),
          ),
          // 최적 방식 (파랑)
          LineChartBarData(
            spots: cumulativeOptimal.asMap().entries.map((e) {
              return FlSpot(e.key.toDouble(), e.value.toDouble());
            }).toList(),
            isCurved: true,
            color: AppColors.chartOptimal,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.chartOptimal.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailTable(
    SimulationResult result,
    PensionInput input,
    NumberFormat formatter,
  ) {
    final visibleRows = result.schedule.take(10).toList();

    return Table(
      columnWidths: {
        0: const FlexColumnWidth(1.3),
        1: const FlexColumnWidth(2),
        2: const FlexColumnWidth(1.5),
        3: const FlexColumnWidth(1.5),
        if (input.hasNps) 4: const FlexColumnWidth(1.3),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(
            color: AppColors.gray100,
            borderRadius: BorderRadius.circular(8),
          ),
          children: [
            const _TableHeader('연차'),
            const _TableHeader('인출 계좌'),
            const _TableHeader('금액'),
            const _TableHeader('세금'),
            if (input.hasNps) const _TableHeader('국민연금'),
          ],
        ),
        ...visibleRows.asMap().entries.map((entry) {
          final index = entry.key;
          final year = entry.value;
          final sources = year.withdrawals
              .map((w) => w.source.displayName.replaceAll(' (', '\n('))
              .join(', ');
          // 국민연금 개시 연도 판정 — 이 해부터 npsAnnualAmount>0이고
          // 직전 해(표시된 첫 행이면 바로 그 해)는 0이었던 경우.
          final isNpsStartYear = input.hasNps &&
              year.npsAnnualAmount > 0 &&
              (index == 0 || visibleRows[index - 1].npsAnnualAmount == 0);
          return TableRow(
            children: [
              _buildYearCell(year, isNpsStartYear),
              _TableCell(sources.isEmpty ? '-' : sources),
              _TableCell('${formatter.format(year.totalAmount ~/ 10000)}만'),
              _TableCell(
                year.totalTax > 0
                    ? '${formatter.format(year.totalTax ~/ 10000)}만'
                    : '-',
              ),
              if (input.hasNps)
                _TableCell(
                  year.npsAnnualAmount > 0
                      ? '${formatter.format(year.npsAnnualAmount ~/ 10000)}만'
                      : '—',
                ),
            ],
          );
        }),
        if (result.schedule.length > 10)
          TableRow(
            children: [
              const _TableCell('...'),
              const _TableCell(''),
              const _TableCell(''),
              const _TableCell(''),
              if (input.hasNps) const _TableCell(''),
            ],
          ),
      ],
    );
  }

  /// '연차' 열 셀 — 국민연금 개시 연도면 배지를 함께 표시한다.
  Widget _buildYearCell(YearlyWithdrawal year, bool isNpsStartYear) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${year.year}년차\n(${year.age}세)',
            style: AppTextStyles.caption,
            textAlign: TextAlign.center,
          ),
          if (isNpsStartYear) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.info,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                '국민연금 개시',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 전략 비교표 — 4전략 토너먼트 전체 결과 (v1.2)
  ///
  /// 우승 판정과 동일한 지표(낸 세금 + 잠재세 = taxBurden) 오름차순으로 정렬해
  /// 우승 전략을 최상단에 강조한다. 데이터는 엔진이 이미 계산한
  /// [SimulationResult.outcomes]를 그대로 표시한다 (추가 계산 없음).
  Widget _buildStrategyComparisonCard(
    SimulationResult result,
    NumberFormat formatter,
  ) {
    if (result.outcomes.isEmpty) return const SizedBox.shrink();
    final sorted = [...result.outcomes]
      ..sort((a, b) => a.taxBurden.compareTo(b.taxBurden));

    String won(int v) => '${formatter.format(v ~/ 10000)}만';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.gray200.withAlpha(128),
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
              const Icon(Icons.compare_arrows, color: AppColors.navy, size: 24),
              const SizedBox(width: 8),
              Text('전략 비교', style: AppTextStyles.h4),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '4가지 인출 전략을 전 기간 시뮬레이션한 결과입니다\n(총 부담 = 낸 세금 + 남은 잔액의 잠재 세금)',
            style: AppTextStyles.caption.copyWith(color: AppColors.gray500),
          ),
          const SizedBox(height: 12),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(2.4),
              1: FlexColumnWidth(1.4),
              2: FlexColumnWidth(1.4),
              3: FlexColumnWidth(1.6),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppColors.gray200),
                  ),
                ),
                children: const [
                  _TableHeader('전략'),
                  _TableHeader('낸 세금'),
                  _TableHeader('잠재세'),
                  _TableHeader('총 부담'),
                ],
              ),
              ...sorted.asMap().entries.map((entry) {
                final isWinner = entry.key == 0;
                final o = entry.value;
                final style = TextStyle(
                  fontSize: 13,
                  height: 1.3,
                  fontWeight: isWinner ? FontWeight.w700 : FontWeight.w400,
                  color: isWinner ? AppColors.navy : AppColors.gray800,
                );
                return TableRow(
                  decoration: BoxDecoration(
                    color: isWinner
                        ? AppColors.green.withAlpha(24)
                        : Colors.transparent,
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        isWinner ? '🏆 ${o.strategyName}' : o.strategyName,
                        style: style,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(won(o.totalTax),
                          textAlign: TextAlign.right, style: style),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(won(o.latentTax),
                          textAlign: TextAlign.right, style: style),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(won(o.taxBurden),
                          textAlign: TextAlign.right, style: style),
                    ),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  /// 몬테카를로 성공 확률 카드 (v1.3)
  ///
  /// 고정 수익률 단일 경로의 약점(수익률 순서 위험)을 보완 — 연 수익률을
  /// 무작위로 흔든 1,000개 미래에서 계획이 성공한 비율과 기말 잔액
  /// 비관/중간/낙관 3구간을 보여준다.
  Widget _buildMonteCarloCard(NumberFormat formatter) {
    final summary = ref.watch(monteCarloProvider);
    if (summary == null) return const SizedBox.shrink();
    String won(int v) => '${formatter.format(v ~/ 10000)}만원';

    Color rateColor(int rate) => rate >= 85
        ? AppColors.green
        : rate >= 60
            ? AppColors.warning
            : AppColors.error;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.gray200.withAlpha(128),
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
                  const Icon(Icons.casino_outlined,
                      color: AppColors.navy, size: 24),
                  const SizedBox(width: 8),
                  Text('계획 성공 확률', style: AppTextStyles.h4),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '수익률이 매년 출렁이는 ${formatter.format(summary.paths)}개의 미래를 시뮬레이션한 결과입니다',
                style: AppTextStyles.caption.copyWith(color: AppColors.gray500),
              ),
              const SizedBox(height: 16),
              Center(
                child: Column(
                  children: [
                    Text(
                      '${summary.successRate}%',
                      style: TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.w700,
                        height: 1.0,
                        color: rateColor(summary.successRate),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${formatter.format(summary.paths)}개 미래 중 ${formatter.format((summary.successRate * summary.paths / 100).round())}개에서 목표 인출 완주',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.gray500),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _mcRow('🌧 비관 (하위 10%)', won(summary.p10FinalBalance)),
              _mcRow('⛅ 중간 (50%)', won(summary.p50FinalBalance)),
              _mcRow('☀️ 낙관 (상위 10%)', won(summary.p90FinalBalance)),
              const SizedBox(height: 12),
              Text(
                '기말 잔액 기준 · 연 변동성 ${(kMcVolatility * 100).round()}% 가정(주식·채권 혼합형 수준) · 최적 전략 고정',
                style: AppTextStyles.caption.copyWith(color: AppColors.gray500),
              ),
            ],
      ),
    );
  }

  Widget _mcRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 13, color: AppColors.gray800)),
          Text(value,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  /// 공유 카드 이미지를 PNG로 캡처해 시스템 공유 시트로 전달 (v1.2)
  Future<void> _shareCardAsImage(String shareText) async {
    final boundary = _shareCardKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) {
      throw StateError('공유 카드를 찾을 수 없습니다');
    }
    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw StateError('이미지 변환에 실패했습니다');
    }
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/pension_compass_result_'
      '${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(byteData.buffer.asUint8List());
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: shareText),
    );
  }

  /// 공유용 한 줄 절세 카드
  Widget _buildShareableCard(SimulationResult result, NumberFormat formatter) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.green, AppColors.greenDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.green.withAlpha(80),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.explore, color: Colors.white, size: 24),
              SizedBox(width: 8),
              Text(
                '연금나침반 최적화 결과',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (result.savings > 0) ...[
            Text(
              '${formatter.format(result.savings ~/ 10000)}만원',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 48,
                fontWeight: FontWeight.w700,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '절감!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(40),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '일반 인출 대비 ${result.savingsRate.toStringAsFixed(1)}% 절감',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ] else ...[
            // 절감액 0 = 전액 비과세 등으로 이미 최적 — "0만원 절감!" 대신 긍정 카피
            const Text(
              '이미 최적 인출 순서입니다',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(40),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                '어떤 순서로 인출해도 세금 차이가 없는 구성입니다',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 시나리오 저장 다이얼로그 (v1.2)
  void _showSaveScenarioDialog(BuildContext context, PensionInput input) {
    final controller =
        TextEditingController(text: SavedScenario.suggestName(input));
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('시나리오로 저장'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              maxLength: 20,
              decoration: const InputDecoration(
                labelText: '시나리오 이름',
                hintText: '예: 60세 은퇴·월 200만원',
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '저장 후 홈 화면 "시나리오 비교"에서 나란히 볼 수 있습니다 (최대 ${LocalStorageService.maxScenarios}개, 같은 이름은 덮어쓰기)',
              style: AppTextStyles.caption.copyWith(color: AppColors.gray500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(dialogContext);
              final ok = await ref
                  .read(savedScenariosProvider.notifier)
                  .save(name, input);
              messenger.showSnackBar(
                SnackBar(
                  content: Text(ok
                      ? '"$name" 시나리오를 저장했습니다'
                      : '최대 ${LocalStorageService.maxScenarios}개까지 저장할 수 있습니다 — 홈의 시나리오 비교에서 정리해 주세요'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  /// 공유 다이얼로그
  void _showShareDialog(BuildContext context, SimulationResult result, NumberFormat formatter) {
    final shareText = '''
🧭 연금나침반 최적화 결과

💰 총 절감액: ${formatter.format(result.savings ~/ 10000)}만원
📉 절감률: ${result.savingsRate.toStringAsFixed(1)}%

📊 최적 인출 순서:
${result.optimalSequence.asMap().entries.map((e) => '${e.key + 1}. ${e.value.displayName}').join('\n')}

내 연금은 얼마나 아낄 수 있을까?
👉 https://play.google.com/store/apps/details?id=com.quantlog.pensioncompass

#연금나침반 #연금저축 #ISA #절세
''';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '결과 공유하기',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            // 미리보기 — 인출 순서가 길면 시트 높이를 넘으므로 스크롤로 수용
            Flexible(
              child: SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.gray100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    shareText,
                    style: const TextStyle(fontSize: 14, height: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: shareText));
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('클립보드에 복사되었습니다'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('텍스트 복사'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.pop(context);
                      try {
                        await _shareCardAsImage(shareText);
                      } catch (e) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('이미지 공유에 실패했습니다: $e'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.share),
                    label: const Text('이미지 공유'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.green,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  final String text;
  const _TableHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        text,
        style: AppTextStyles.captionBold,
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _TableCell extends StatelessWidget {
  final String text;
  const _TableCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        text,
        style: AppTextStyles.caption,
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// 비교 항목 행 (기존 방식 설명용)
class _ComparisonRow extends StatelessWidget {
  final String order;
  final String text;
  final bool isOptimal;

  const _ComparisonRow({
    required this.order,
    required this.text,
    required this.isOptimal,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: isOptimal ? AppColors.green : AppColors.gray400,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Center(
              child: Text(
                order,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: isOptimal ? AppColors.green : AppColors.gray600,
              ),
            ),
          ),
          Icon(
            isOptimal ? Icons.check_circle : Icons.cancel,
            size: 18,
            color: isOptimal ? AppColors.green : AppColors.gray400,
          ),
        ],
      ),
    );
  }
}
