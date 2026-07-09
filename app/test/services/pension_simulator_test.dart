import 'package:flutter_test/flutter_test.dart';
import 'package:pension_compass/models/simulation_result.dart';
import 'package:pension_compass/services/pension_simulator.dart';
import 'package:pension_compass/services/withdrawal_strategies.dart';

void main() {
  group('payoutLimitFor — 연금수령한도 10년 룰', () {
    test('1년차: 평가액 1억 → 1,200만원 (1억/(11-1)×1.2)', () {
      final pools = {WithdrawalSource.pensionDeducted: 100000000};
      expect(PensionSimulator.payoutLimitFor(pools, 1), 12000000);
    });

    test('10년차: 평가액 1억 → 1.2억', () {
      final pools = {WithdrawalSource.pensionDeducted: 100000000};
      expect(PensionSimulator.payoutLimitFor(pools, 10), 120000000);
    });

    test('11년차 이후: 무제한', () {
      final pools = {WithdrawalSource.pensionDeducted: 100000000};
      expect(PensionSimulator.payoutLimitFor(pools, 11), greaterThan(1000000000000));
    });

    test('ISA 풀은 평가액에서 제외', () {
      final pools = {
        WithdrawalSource.pensionDeducted: 100000000,
        WithdrawalSource.isaPrincipal: 999999999999, // 포함되면 한도 폭증
      };
      expect(PensionSimulator.payoutLimitFor(pools, 1), 12000000);
    });
  });

  group('finalizeYearTax — 연말 세금 확정', () {
    DrawSplit split(int within, [int over = 0]) =>
        DrawSplit()..within = within..over = over;

    test('비과세 소스는 세금 0', () {
      final details = PensionSimulator.finalizeYearTax(
        {WithdrawalSource.pensionNonDeducted: split(10000000)}, 58, 1);
      expect(details.single.tax, 0);
    });

    test('과세재원 1,500만원 이하 → 저율 5.5% (58세)', () {
      final details = PensionSimulator.finalizeYearTax(
        {WithdrawalSource.pensionDeducted: split(15000000)}, 58, 1);
      expect(details.single.tax, 825000); // 15,000,000 × 5.5%
    });

    test('절벽: 1,500만원+1원 → 전액 16.5%', () {
      final details = PensionSimulator.finalizeYearTax(
        {WithdrawalSource.pensionDeducted: split(15000001)}, 58, 1);
      expect(details.single.tax, 2475000); // round(15,000,001 × 16.5%)
    });

    test('절벽은 과세재원 합산으로 판정 (공제분 1,000만 + IRP 600만 = 1,600만)', () {
      final details = PensionSimulator.finalizeYearTax({
        WithdrawalSource.pensionDeducted: split(10000000),
        WithdrawalSource.irpSelf: split(6000000),
      }, 58, 1);
      final totalTax = details.fold<int>(0, (s, d) => s + d.tax);
      expect(totalTax, 2640000); // 16,000,000 × 16.5%
    });

    test('수령한도 초과분(over)은 16.5%, 한도 내는 저율 유지 (절벽 미발동)', () {
      final details = PensionSimulator.finalizeYearTax(
        {WithdrawalSource.pensionDeducted: split(12000000, 3000000)}, 58, 1);
      final totalTax = details.fold<int>(0, (s, d) => s + d.tax);
      expect(totalTax, 1155000); // 12M×5.5% + 3M×16.5% = 660,000 + 495,000
    });

    test('나이별 저율: 70세 4.4%, 80세 3.3%', () {
      final at70 = PensionSimulator.finalizeYearTax(
        {WithdrawalSource.pensionDeducted: split(10000000)}, 70, 1);
      final at80 = PensionSimulator.finalizeYearTax(
        {WithdrawalSource.pensionDeducted: split(10000000)}, 80, 1);
      expect(at70.single.tax, 440000);
      expect(at80.single.tax, 330000);
    });

    test('퇴직금: 1~10년차 3.5%, 11년차부터 3.0%, 한도 초과 5.0%', () {
      final y5 = PensionSimulator.finalizeYearTax(
        {WithdrawalSource.irpRetirement: split(10000000)}, 60, 5);
      final y11 = PensionSimulator.finalizeYearTax(
        {WithdrawalSource.irpRetirement: split(10000000)}, 66, 11);
      final over = PensionSimulator.finalizeYearTax(
        {WithdrawalSource.irpRetirement: split(0, 10000000)}, 60, 5);
      expect(y5.single.tax, 350000);
      expect(y11.single.tax, 300000);
      expect(over.single.tax, 500000);
    });

    test('퇴직금 인출은 절벽 판정에 미포함', () {
      final details = PensionSimulator.finalizeYearTax({
        WithdrawalSource.pensionDeducted: split(14000000),
        WithdrawalSource.irpRetirement: split(20000000),
      }, 58, 1);
      final pension = details.firstWhere(
        (d) => d.source == WithdrawalSource.pensionDeducted);
      expect(pension.tax, 770000); // 절벽 미발동 — 14M × 5.5%
    });
  });

  group('kStrategies — 전략 정의', () {
    test('4개 전략, id 유일, pension_first 포함', () {
      expect(kStrategies.length, 4);
      final ids = kStrategies.map((s) => s.id).toSet();
      expect(ids.length, 4);
      expect(ids, contains('pension_first'));
      expect(kStrategies.first.id, 'fill_bracket'); // 동률 시 우선
    });

    test('fill_bracket: 과세재원 스텝은 bracket+payout 캡 준수', () {
      final fb = kStrategies.firstWhere((s) => s.id == 'fill_bracket');
      final first = fb.steps.first;
      expect(first.source, WithdrawalSource.pensionDeducted);
      expect(first.useBracketCap, true);
      expect(first.usePayoutCap, true);
    });

    test('defer_taxable: 과세재원은 70세부터 활성', () {
      final dt = kStrategies.firstWhere((s) => s.id == 'defer_taxable');
      final taxableSteps = dt.steps
          .where((s) => kBracketSources.contains(s.source));
      expect(taxableSteps.every((s) => s.activeFromAge == 70), true);
    });
  });
}
