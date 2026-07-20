import 'package:flutter_test/flutter_test.dart';

import 'package:pension_compass/models/pension_input.dart';
import 'package:pension_compass/models/simulation_result.dart';
import 'package:pension_compass/services/monte_carlo_simulator.dart';
import 'package:pension_compass/services/pension_simulator.dart';
import 'package:pension_compass/services/withdrawal_optimizer.dart';
import 'package:pension_compass/services/withdrawal_strategies.dart';

/// v1.3 — 몬테카를로 성공률 시뮬레이터 단위 테스트.
void main() {
  const richInput = PensionInput(
    pensionSavings: 500000000, // 5억 — 연 2,400만 인출에 넉넉
    pensionSavingsDeducted: 0,
    irpBalance: 0,
    irpRetirementPortion: 0,
    isaMaturity: 0,
    currentAge: 58,
    targetAnnualWithdrawal: 24000000,
    simulationYears: 10,
    expectedReturnRate: 0.04,
  );

  const poorInput = PensionInput(
    pensionSavings: 50000000, // 5천만 — 연 2,400만 인출이면 2~3년 고갈
    pensionSavingsDeducted: 0,
    irpBalance: 0,
    irpRetirementPortion: 0,
    isaMaturity: 0,
    currentAge: 58,
    targetAnnualWithdrawal: 24000000,
    simulationYears: 20,
    expectedReturnRate: 0.04,
  );

  String winnerOf(PensionInput input) =>
      WithdrawalOptimizer.optimize(input).optimalStrategyId;

  test('변동성 0 → 전 경로 동일 = 결정적 엔진과 일치 (백분위 3개 동일)', () {
    final winner = winnerOf(richInput);
    final mc = MonteCarloSimulator.simulate(
      richInput, winner, paths: 50, volatility: 0);
    final det = PensionSimulator.run(
      richInput,
      kStrategies.firstWhere((s) => s.id == winner),
    );
    expect(mc.successRate, 100);
    expect(mc.p10FinalBalance, mc.p50FinalBalance);
    expect(mc.p50FinalBalance, mc.p90FinalBalance);
    expect(mc.p50FinalBalance, det.finalBalance);
  });

  test('같은 입력 = 같은 결과 (결정적 시드)', () {
    final winner = winnerOf(richInput);
    final a = MonteCarloSimulator.simulate(richInput, winner, paths: 200);
    final b = MonteCarloSimulator.simulate(richInput, winner, paths: 200);
    expect(a.successRate, b.successRate);
    expect(a.p50FinalBalance, b.p50FinalBalance);
  });

  test('넉넉한 자산 → 높은 성공률, 부족한 자산 → 낮은 성공률', () {
    final rich = MonteCarloSimulator.simulate(
      richInput, winnerOf(richInput), paths: 300);
    final poor = MonteCarloSimulator.simulate(
      poorInput, winnerOf(poorInput), paths: 300);
    expect(rich.successRate, greaterThanOrEqualTo(90));
    expect(poor.successRate, lessThanOrEqualTo(10));
  });

  test('손실 연도로 earnings 풀이 음수여도 수령한도는 0 하한 (회귀 가드)', () {
    // MC 실측 크래시: 음수 평가액 → 음수 한도 → clamp(0, 음수) ArgumentError
    final pools = {
      WithdrawalSource.pensionDeducted: 10000000,
      WithdrawalSource.earnings: -50000000,
    };
    expect(PensionSimulator.payoutLimitFor(pools, 1), 0);
  });

  test('과세재원 혼합 입력에서도 전 경로 정상 완주 (실측 크래시 입력)', () {
    const mixed = PensionInput(
      pensionSavings: 100000000,
      pensionSavingsDeducted: 100000000,
      irpBalance: 50000000,
      irpRetirementPortion: 40000000,
      isaMaturity: 30000000,
      isaProfit: 5000000,
      currentAge: 58,
      targetAnnualWithdrawal: 24000000,
      simulationYears: 10,
      expectedReturnRate: 0.04,
    );
    final mc = MonteCarloSimulator.simulate(mixed, winnerOf(mixed));
    expect(mc.paths, kMcFreePaths);
    expect(mc.successRate, inInclusiveRange(0, 100));
  });

  test('백분위 순서 p10 <= p50 <= p90', () {
    final mc = MonteCarloSimulator.simulate(
      richInput, winnerOf(richInput), paths: 300);
    expect(mc.p10FinalBalance, lessThanOrEqualTo(mc.p50FinalBalance));
    expect(mc.p50FinalBalance, lessThanOrEqualTo(mc.p90FinalBalance));
  });

  test('1,000경로 소요 시간 측정 (동기 실행 판단 근거)', () {
    final winner = winnerOf(richInput);
    final sw = Stopwatch()..start();
    MonteCarloSimulator.simulate(richInput, winner);
    sw.stop();
    // JIT 테스트 환경 기준 상한 — AOT(실기기)는 이보다 빠르다
    // ignore: avoid_print
    print('MC 1000 paths: ${sw.elapsedMilliseconds}ms');
    expect(sw.elapsedMilliseconds, lessThan(3000));
  });
}
