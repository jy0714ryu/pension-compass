import 'dart:math';

import '../models/pension_input.dart';
import '../models/simulation_result.dart';
import 'pension_simulator.dart';
import 'withdrawal_strategies.dart';

/// 몬테카를로 성공률 시뮬레이터 (v1.3)
///
/// 고정 수익률 단일 경로의 한계(수익률 순서 위험 미반영)를 보완한다:
/// 연 수익률을 정규분포(평균 = 입력 수익률, 표준편차 = [kMcVolatility])에서
/// 무작위로 뽑아 같은 인출 계획을 [kMcFreePaths]번 반복 시뮬레이션하고,
/// "인출기(55세+) 전 연차에 목표 인출을 채운 경로"의 비율을 성공률로 낸다.
///
/// 결정성: 시드를 입력값 해시에서 유도 — 같은 입력이면 항상 같은 결과
/// (재계산할 때마다 확률이 바뀌면 신뢰를 잃는다). 전략은 결정적 토너먼트
/// 우승 전략 1개를 고정 사용한다 (경로마다 토너먼트를 다시 돌리지 않음).
///
/// 단순화 주의: 손실 연도(-수익률)의 감소분은 성장분과 같은 운용수익
/// (과세 earnings) 풀에 반영된다 — 과세 대상 수익이 먼저 상쇄되는 셈이라
/// 손익통산에 준하는 근사다. 확률 요약 목적에는 충분하며 세액 자문이 아니다.

/// 연 수익률 변동성 (표준편차) — 주식·채권 혼합형 포트폴리오 수준 가정
const double kMcVolatility = 0.10;

/// 무료 티어 경로 수 (정밀 모드는 프리미엄 예약)
const int kMcFreePaths = 1000;

class MonteCarloSummary {
  /// 성공 확률 (0~100, 정수 반올림)
  final int successRate;

  /// 기말 잔액 백분위 (원) — 비관 p10 / 중간 p50 / 낙관 p90
  final int p10FinalBalance;
  final int p50FinalBalance;
  final int p90FinalBalance;

  /// 시뮬레이션 경로 수
  final int paths;

  const MonteCarloSummary({
    required this.successRate,
    required this.p10FinalBalance,
    required this.p50FinalBalance,
    required this.p90FinalBalance,
    required this.paths,
  });
}

class MonteCarloSimulator {
  MonteCarloSimulator._();

  /// 입력값 기반 결정적 시드 (같은 입력 = 같은 결과)
  static int seedFor(PensionInput input) =>
      Object.hash(
        input.pensionSavings,
        input.pensionSavingsDeducted,
        input.irpBalance,
        input.irpRetirementPortion,
        input.isaMaturity,
        input.isaProfit,
        input.currentAge,
        input.targetAnnualWithdrawal,
        input.simulationYears,
        (input.expectedReturnRate * 10000).round(),
        input.npsMonthlyAmount,
        input.npsStartAge,
      ) &
      0x7fffffff;

  /// [strategyId] 전략으로 [paths]개 경로를 시뮬레이션해 요약을 낸다.
  static MonteCarloSummary simulate(
    PensionInput input,
    String strategyId, {
    int paths = kMcFreePaths,
    double volatility = kMcVolatility,
    int? seed,
  }) {
    final strategy = kStrategies.firstWhere(
      (s) => s.id == strategyId,
      orElse: () => kStrategies.first,
    );
    final rng = Random(seed ?? seedFor(input));

    var successCount = 0;
    final finals = List<int>.filled(paths, 0);

    for (var p = 0; p < paths; p++) {
      final returns = List<double>.generate(
        input.simulationYears,
        (_) => _gaussian(rng, input.expectedReturnRate, volatility),
      );
      final outcome =
          PensionSimulator.run(input, strategy, yearlyReturns: returns);
      finals[p] = outcome.finalBalance;
      if (_pathSucceeded(input, outcome)) successCount++;
    }

    finals.sort();
    int pct(int p) => finals[((finals.length - 1) * p / 100).round()];

    return MonteCarloSummary(
      successRate: (successCount * 100 / paths).round(),
      p10FinalBalance: pct(10),
      p50FinalBalance: pct(50),
      p90FinalBalance: pct(90),
      paths: paths,
    );
  }

  /// 성공 판정 — 인출기(55세+) 전 연차에서 목표(국민연금 차감 후)를 채웠는가.
  /// result_narrative 의 고갈 판정과 동일한 규칙 (적립기 행 제외).
  static bool _pathSucceeded(PensionInput input, StrategyOutcome outcome) {
    for (final row in outcome.schedule) {
      if (row.age < kPensionWithdrawalMinAge) continue;
      final target = (input.targetAnnualWithdrawal - row.npsAnnualAmount)
          .clamp(0, 1 << 60);
      if (row.totalAmount < target) return false;
    }
    // 잔액 조기 소진으로 schedule 이 짧게 끝난 경우: 남은 인출기 연차만큼 실패
    final lastAge = input.currentAge + outcome.schedule.length - 1;
    final endAge = input.currentAge + input.simulationYears - 1;
    if (lastAge < endAge && endAge >= kPensionWithdrawalMinAge) {
      return false;
    }
    return true;
  }

  /// Box-Muller 정규분포 난수 (평균 mean, 표준편차 sigma), 수익률 하한 -95%
  static double _gaussian(Random rng, double mean, double sigma) {
    final u1 = rng.nextDouble().clamp(1e-12, 1.0);
    final u2 = rng.nextDouble();
    final z = sqrt(-2 * log(u1)) * cos(2 * pi * u2);
    return (mean + sigma * z).clamp(-0.95, 5.0);
  }
}
