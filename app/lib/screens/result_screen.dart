import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../providers/pension_provider.dart';
import '../models/simulation_result.dart';
import '../services/local_storage_service.dart';
import '../services/in_app_review_service.dart';
import '../widgets/banner_ad_widget.dart';

class ResultScreen extends ConsumerStatefulWidget {
  final LocalStorageService? storage;

  const ResultScreen({super.key, this.storage});

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  bool _reviewRequested = false;

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
            // 한 줄 절세 요약 카드 (공유용)
            _buildShareableCard(result, formatter),
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
                          subtitle: '비과세부터 인출',
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
                        Text(
                          '${formatter.format(result.savings ~/ 10000)}만원 절감',
                          style: const TextStyle(
                            color: AppColors.green,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
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
                  const SizedBox(height: 16),
                  _buildDetailTable(result, formatter),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 전문가 팁 & 안내사항
            _buildExpertTips(),
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

  /// 전문가 팁 & 안내사항 위젯
  Widget _buildExpertTips() {
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
    
    // 기존 방식 누적 세금 계산 (간이)
    final cumulativeBaseline = <int>[];
    int cumulative = 0;
    for (int i = 0; i < result.schedule.length; i++) {
      // 기존 방식은 연 평균 세금이 더 높다고 가정
      cumulative += (result.totalTaxBaseline / result.schedule.length).round();
      cumulativeBaseline.add(cumulative);
    }

    final maxY = (cumulativeBaseline.isNotEmpty
            ? cumulativeBaseline.last
            : cumulativeOptimal.last)
        .toDouble();

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

  Widget _buildDetailTable(SimulationResult result, NumberFormat formatter) {
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(1),
        1: FlexColumnWidth(2),
        2: FlexColumnWidth(1.5),
        3: FlexColumnWidth(1.5),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(
            color: AppColors.gray100,
            borderRadius: BorderRadius.circular(8),
          ),
          children: const [
            _TableHeader('연차'),
            _TableHeader('인출 계좌'),
            _TableHeader('금액'),
            _TableHeader('세금'),
          ],
        ),
        ...result.schedule.take(10).map((year) {
          final sources = year.withdrawals
              .map((w) => w.source.displayName.replaceAll(' (', '\n('))
              .join(', ');
          return TableRow(
            children: [
              _TableCell('${year.year}년차\n(${year.age}세)'),
              _TableCell(sources.isEmpty ? '-' : sources),
              _TableCell('${formatter.format(year.totalAmount ~/ 10000)}만'),
              _TableCell(
                year.totalTax > 0
                    ? '${formatter.format(year.totalTax ~/ 10000)}만'
                    : '-',
              ),
            ],
          );
        }),
        if (result.schedule.length > 10)
          const TableRow(
            children: [
              _TableCell('...'),
              _TableCell(''),
              _TableCell(''),
              _TableCell(''),
            ],
          ),
      ],
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
            Container(
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
                    onPressed: () {
                      // TODO: 이미지 캡처 및 공유 기능 (share_plus 패키지 필요)
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('이미지 공유 기능은 추후 업데이트 예정입니다'),
                          duration: Duration(seconds: 2),
                        ),
                      );
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
