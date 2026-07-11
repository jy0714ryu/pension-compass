import 'package:flutter_test/flutter_test.dart';
import 'package:pension_compass/models/pension_input.dart';
import 'package:pension_compass/models/simulation_result.dart';
import 'package:pension_compass/services/result_narrative.dart';

/// v1.1 Task 6 — 결과 화면 내러티브·크레바스 순수 계산 로직 단위 테스트.
void main() {
  YearlyWithdrawal fundedYear({
    required int year,
    required int age,
    required int amount,
    int npsAnnualAmount = 0,
  }) {
    return YearlyWithdrawal(
      year: year,
      age: age,
      npsAnnualAmount: npsAnnualAmount,
      withdrawals: amount > 0
          ? [
              WithdrawalDetail(
                source: WithdrawalSource.pensionNonDeducted,
                amount: amount,
                tax: 0,
                taxRate: 0,
              ),
            ]
          : const [],
    );
  }

  const baseInput = PensionInput(
    pensionSavings: 100000000,
    pensionSavingsDeducted: 0,
    irpBalance: 0,
    irpRetirementPortion: 0,
    isaMaturity: 0,
    currentAge: 58,
    targetAnnualWithdrawal: 20000000,
    simulationYears: 5,
    expectedReturnRate: 0,
  );

  group('computeWithdrawalNarrative — 고갈 없음(완주)', () {
    test('전 기간 목표 인출을 다 채우면 fundedYears=스케줄 길이, depleted=false', () {
      final schedule = List.generate(
        5,
        (i) => fundedYear(year: i + 1, age: 58 + i, amount: 20000000),
      );
      final result = SimulationResult(
        schedule: schedule,
        totalTaxOptimal: 0,
        totalTaxBaseline: 0,
        optimalSequence: const [],
      );

      final narrative = computeWithdrawalNarrative(result, baseInput);

      expect(narrative.monthlyWithdrawal, (20000000 / 12).round());
      expect(narrative.fundedYears, 5);
      expect(narrative.depleted, false);
      expect(narrative.depletionAge, isNull);
    });
  });

  group('computeWithdrawalNarrative — 중간 고갈', () {
    test('목표 미달 첫 해가 고갈 나이, fundedYears는 그 이전 연수', () {
      final schedule = [
        fundedYear(year: 1, age: 58, amount: 20000000),
        fundedYear(year: 2, age: 59, amount: 20000000),
        fundedYear(year: 3, age: 60, amount: 20000000),
        // 4년차부터 잔액 부족 — 목표(2천만) 미달
        fundedYear(year: 4, age: 61, amount: 8000000),
        fundedYear(year: 5, age: 62, amount: 0),
      ];
      final result = SimulationResult(
        schedule: schedule,
        totalTaxOptimal: 0,
        totalTaxBaseline: 0,
        optimalSequence: const [],
      );

      final narrative = computeWithdrawalNarrative(result, baseInput);

      expect(narrative.fundedYears, 3);
      expect(narrative.depleted, true);
      expect(narrative.depletionAge, 61);
    });
  });

  group('computeWithdrawalNarrative — 국민연금 반영 시 목표 인출액 차감', () {
    test('국민연금이 목표를 채워주면 계좌 인출이 적어도 고갈로 취급하지 않는다', () {
      // 목표 2천만 중 국민연금이 720만을 채워주므로 계좌 인출 목표는 1,280만.
      // 실제 인출이 정확히 1,280만이면 미달이 아니다.
      final schedule = [
        fundedYear(year: 1, age: 65, amount: 12800000, npsAnnualAmount: 7200000),
      ];
      final input = baseInput.copyWith(
        currentAge: 65,
        simulationYears: 1,
        npsMonthlyAmount: 600000,
        npsStartAge: 65,
      );
      final result = SimulationResult(
        schedule: schedule,
        totalTaxOptimal: 0,
        totalTaxBaseline: 0,
        optimalSequence: const [],
      );

      final narrative = computeWithdrawalNarrative(result, input);

      expect(narrative.fundedYears, 1);
      expect(narrative.depleted, false);
    });
  });

  group('computeCrevasseSummary — 공백기 있음', () {
    test('개시 전 공백기 연수·대표 인출액과 개시 후 대표 인출액을 계산한다', () {
      final input = baseInput.copyWith(
        currentAge: 58,
        simulationYears: 10,
        npsMonthlyAmount: 600000,
        npsStartAge: 65,
      );
      final schedule = [
        fundedYear(year: 1, age: 58, amount: 20000000),
        fundedYear(year: 2, age: 59, amount: 20000000),
        fundedYear(year: 3, age: 60, amount: 20000000),
        fundedYear(year: 4, age: 61, amount: 20000000),
        fundedYear(year: 5, age: 62, amount: 20000000),
        fundedYear(year: 6, age: 63, amount: 20000000),
        fundedYear(year: 7, age: 64, amount: 20000000),
        fundedYear(
            year: 8, age: 65, amount: 12800000, npsAnnualAmount: 7200000),
        fundedYear(
            year: 9, age: 66, amount: 12800000, npsAnnualAmount: 7200000),
        fundedYear(
            year: 10, age: 67, amount: 12800000, npsAnnualAmount: 7200000),
      ];
      final result = SimulationResult(
        schedule: schedule,
        totalTaxOptimal: 0,
        totalTaxBaseline: 0,
        optimalSequence: const [],
      );

      final crevasse = computeCrevasseSummary(result, input);

      expect(crevasse.gapYears, 7);
      expect(crevasse.preNpsAnnualWithdrawal, 20000000);
      expect(crevasse.postNpsAnnualWithdrawal, 12800000);
      expect(crevasse.startYearIndex, 7);
    });
  });

  group('computeCrevasseSummary — 개시연령이 이미 시작 나이 이상 (공백기 0년)', () {
    test('gapYears=0, preNpsAnnualWithdrawal=0', () {
      final input = baseInput.copyWith(
        currentAge: 65,
        simulationYears: 3,
        npsMonthlyAmount: 600000,
        npsStartAge: 65,
      );
      final schedule = [
        fundedYear(
            year: 1, age: 65, amount: 12800000, npsAnnualAmount: 7200000),
        fundedYear(
            year: 2, age: 66, amount: 12800000, npsAnnualAmount: 7200000),
        fundedYear(
            year: 3, age: 67, amount: 12800000, npsAnnualAmount: 7200000),
      ];
      final result = SimulationResult(
        schedule: schedule,
        totalTaxOptimal: 0,
        totalTaxBaseline: 0,
        optimalSequence: const [],
      );

      final crevasse = computeCrevasseSummary(result, input);

      expect(crevasse.gapYears, 0);
      expect(crevasse.preNpsAnnualWithdrawal, 0);
      expect(crevasse.postNpsAnnualWithdrawal, 12800000);
      expect(crevasse.startYearIndex, 0);
    });
  });

  group('computeCrevasseSummary — 시뮬레이션 기간이 개시 전에 끝남', () {
    test('startYearIndex/postNpsAnnualWithdrawal 모두 null, gapYears=전체 길이', () {
      final input = baseInput.copyWith(
        currentAge: 58,
        simulationYears: 3,
        npsMonthlyAmount: 600000,
        npsStartAge: 65,
      );
      final schedule = [
        fundedYear(year: 1, age: 58, amount: 20000000),
        fundedYear(year: 2, age: 59, amount: 20000000),
        fundedYear(year: 3, age: 60, amount: 20000000),
      ];
      final result = SimulationResult(
        schedule: schedule,
        totalTaxOptimal: 0,
        totalTaxBaseline: 0,
        optimalSequence: const [],
      );

      final crevasse = computeCrevasseSummary(result, input);

      expect(crevasse.gapYears, 3);
      expect(crevasse.startYearIndex, isNull);
      expect(crevasse.postNpsAnnualWithdrawal, isNull);
    });
  });
}
