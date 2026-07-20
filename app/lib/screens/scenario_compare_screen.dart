import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/pension_input.dart';
import '../models/saved_scenario.dart';
import '../models/simulation_result.dart';
import '../providers/pension_provider.dart';
import '../services/result_narrative.dart';
import '../services/withdrawal_optimizer.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// 시나리오 2-up 비교 화면 (v1.2)
///
/// 저장된 시나리오는 **입력값만** 담고 있으므로 결과는 진입 시 결정적 엔진으로
/// 즉시 재계산한다 (온디바이스, 수 ms). "60세 은퇴 vs 63세 은퇴",
/// "월 200 vs 250" 같은 선택지를 나란히 놓고 세금·지속연수를 비교한다.
class ScenarioCompareScreen extends ConsumerStatefulWidget {
  const ScenarioCompareScreen({super.key});

  @override
  ConsumerState<ScenarioCompareScreen> createState() =>
      _ScenarioCompareScreenState();
}

class _ScenarioCompareScreenState extends ConsumerState<ScenarioCompareScreen> {
  String? _nameA;
  String? _nameB;

  @override
  void initState() {
    super.initState();
    ref.read(savedScenariosProvider.notifier).load();
  }

  @override
  Widget build(BuildContext context) {
    final scenarios = ref.watch(savedScenariosProvider);
    final formatter = NumberFormat('#,###');

    // 기본 선택: 최신 2개
    final names = scenarios.map((s) => s.name).toList();
    final nameA = names.contains(_nameA) ? _nameA : names.firstOrNull;
    final nameB = names.contains(_nameB) && _nameB != nameA
        ? _nameB
        : names.where((n) => n != nameA).firstOrNull;

    final a = scenarios.where((s) => s.name == nameA).firstOrNull;
    final b = scenarios.where((s) => s.name == nameB).firstOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('시나리오 비교'),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: scenarios.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  '저장된 시나리오가 없습니다.\n\n결과 화면에서 "시나리오로 저장"을 누르면\n여기서 나란히 비교할 수 있습니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.gray500, height: 1.6),
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildScenarioChips(scenarios),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildPicker(
                          label: 'A',
                          color: AppColors.navy,
                          value: nameA,
                          names: names,
                          onChanged: (v) => setState(() => _nameA = v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildPicker(
                          label: 'B',
                          color: AppColors.green,
                          value: nameB,
                          names: names,
                          onChanged: (v) => setState(() => _nameB = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (a != null && b != null && a.name != b.name)
                    _buildCompareTable(a, b, formatter)
                  else
                    Container(
                      padding: const EdgeInsets.all(24),
                      alignment: Alignment.center,
                      child: const Text(
                        '비교하려면 서로 다른 시나리오 2개가 필요합니다',
                        style: TextStyle(color: AppColors.gray500),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  /// 저장 목록 칩 (삭제 지원)
  Widget _buildScenarioChips(List<SavedScenario> scenarios) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: scenarios
          .map(
            (s) => Chip(
              label: Text(s.name, style: const TextStyle(fontSize: 13)),
              deleteIcon: const Icon(Icons.close, size: 16),
              onDeleted: () =>
                  ref.read(savedScenariosProvider.notifier).remove(s.name),
            ),
          )
          .toList(),
    );
  }

  Widget _buildPicker({
    required String label,
    required Color color,
    required String? value,
    required List<String> names,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: color,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              style: const TextStyle(fontSize: 13, color: AppColors.gray800),
              items: names
                  .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompareTable(
    SavedScenario a,
    SavedScenario b,
    NumberFormat formatter,
  ) {
    final ra = WithdrawalOptimizer.optimize(a.input);
    final rb = WithdrawalOptimizer.optimize(b.input);
    final na = computeWithdrawalNarrative(ra, a.input);
    final nb = computeWithdrawalNarrative(rb, b.input);

    String won(int v) => '${formatter.format(v ~/ 10000)}만원';
    String monthly(PensionInput i) =>
        '${formatter.format((i.targetAnnualWithdrawal / 12 / 10000).round())}만원';
    String duration(WithdrawalNarrative n) => n.depleted
        ? '${n.fundedYears}년 (${n.depletionAge}세 부족)'
        : '${n.fundedYears}년 여유';

    int finalBalance(SimulationResult r) {
      for (final o in r.outcomes) {
        if (o.strategyId == r.optimalStrategyId) return o.finalBalance;
      }
      return 0;
    }

    final rows = <(String, String, String)>[
      ('현재 나이', '${a.input.currentAge}세', '${b.input.currentAge}세'),
      ('월 목표 인출', monthly(a.input), monthly(b.input)),
      ('총 세금 (최적)', won(ra.totalTaxOptimal), won(rb.totalTaxOptimal)),
      ('절감액', won(ra.savings), won(rb.savings)),
      ('인출 지속', duration(na), duration(nb)),
      ('기말 잔액', won(finalBalance(ra)), won(finalBalance(rb))),
      ('우승 전략', ra.optimalStrategyName, rb.optimalStrategyName),
    ];

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
              const Icon(Icons.balance, color: AppColors.navy, size: 24),
              const SizedBox(width: 8),
              Text('나란히 비교', style: AppTextStyles.h4),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '두 시나리오 모두 방금 최신 세법 기준으로 다시 계산했습니다',
            style: AppTextStyles.caption.copyWith(color: AppColors.gray500),
          ),
          const SizedBox(height: 12),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(1.6),
              1: FlexColumnWidth(1.7),
              2: FlexColumnWidth(1.7),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.gray200)),
                ),
                children: [
                  const SizedBox.shrink(),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'A. ${a.name}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'B. ${b.name}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.green,
                      ),
                    ),
                  ),
                ],
              ),
              ...rows.map(
                (row) => TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        row.$1,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.gray500,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(row.$2,
                          style: const TextStyle(fontSize: 13, height: 1.3)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(row.$3,
                          style: const TextStyle(fontSize: 13, height: 1.3)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
