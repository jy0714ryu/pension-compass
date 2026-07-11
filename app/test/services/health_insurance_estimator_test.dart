import 'package:flutter_test/flutter_test.dart';
import 'package:pension_compass/services/health_insurance_estimator.dart';

void main() {
  group('estimate — 산식 손계산 검증 (TAX_RULES §8.2~8.4)', () {
    // 공통 산식:
    // 부과 대상 소득(연) = 공적연금소득×50% + 기타소득×100%
    // 월 건강보험료(raw) = 부과 대상 소득 ÷ 12 × 7.19%, 하한 20,160원 적용
    // 월 장기요양보험료 = 월 건강보험료 × 13.14%

    test('국민연금 연 1,200만원만 있는 경우 (exec-plan 예시값)', () {
      // 부과소득 = 12,000,000 × 0.5 = 6,000,000
      // 월 건보료 = 6,000,000/12 × 0.0719 = 500,000 × 0.0719 = 35,950원
      // 장기요양 = 35,950 × 0.1314 = 4,723.83 → round 4,724원
      // 월 합계 = 35,950 + 4,724 = 40,674원 / 연 합계 = 40,674 × 12 = 488,088원
      final result = HealthInsuranceEstimator.estimate(
        const HealthInsuranceEstimateInput(annualPublicPensionIncome: 12000000),
      );

      expect(result.annualAssessedIncome, 6000000);
      expect(result.monthlyHealthInsurancePremium, 35950);
      expect(result.monthlyLtcPremium, 4724);
      expect(result.monthlyTotalPremium, 40674);
      expect(result.annualTotalPremium, 488088);
      expect(result.isFloorApplied, false);
      expect(result.isEstimate, true);
      expect(result.appliedHealthInsuranceRate, 0.0719);
      expect(result.appliedLtcRate, 0.1314);
    });

    test('국민연금 연 3,000만원 (부과소득 1,500만원)', () {
      // 부과소득 = 30,000,000 × 0.5 = 15,000,000
      // 월 건보료 = 15,000,000/12 × 0.0719 = 1,250,000 × 0.0719 = 89,875원
      // 장기요양 = 89,875 × 0.1314 = 11,810.325 → round 11,810원
      // 월 합계 = 89,875 + 11,810 = 101,685원 / 연 합계 = 1,220,220원
      final result = HealthInsuranceEstimator.estimate(
        const HealthInsuranceEstimateInput(annualPublicPensionIncome: 30000000),
      );

      expect(result.annualAssessedIncome, 15000000);
      expect(result.monthlyHealthInsurancePremium, 89875);
      expect(result.monthlyLtcPremium, 11810);
      expect(result.monthlyTotalPremium, 101685);
      expect(result.annualTotalPremium, 1220220);
      expect(result.isFloorApplied, false);
    });

    test('국민연금 연 1,200만원 + 기타소득 연 500만원 혼합', () {
      // 부과소득 = 12,000,000×0.5 + 5,000,000×1.0 = 6,000,000 + 5,000,000 = 11,000,000
      // 월 건보료 = 11,000,000/12 × 0.0719 = 916,666.666... × 0.0719 = 65,908.33...
      //           → round 65,908원
      // 장기요양 = 65,908 × 0.1314 = 8,660.3112 → round 8,660원
      // 월 합계 = 65,908 + 8,660 = 74,568원 / 연 합계 = 894,816원
      final result = HealthInsuranceEstimator.estimate(
        const HealthInsuranceEstimateInput(
          annualPublicPensionIncome: 12000000,
          annualOtherIncome: 5000000,
        ),
      );

      expect(result.annualAssessedIncome, 11000000);
      expect(result.monthlyHealthInsurancePremium, 65908);
      expect(result.monthlyLtcPremium, 8660);
      expect(result.monthlyTotalPremium, 74568);
      expect(result.annualTotalPremium, 894816);
      expect(result.isFloorApplied, false);
    });
  });

  group('estimate — 의미론 불변식 (Task 2 연액↔월액 혼동 교훈 반영)', () {
    test('공적연금만 있을 때 월 건보료/월 연금액 비율 ≈ 요율×50% (부과소득 커서 하한 미적용)', () {
      // pension 1억원 → 하한(20,160원)에 걸리지 않을 만큼 충분히 큰 값으로 검증
      final result = HealthInsuranceEstimator.estimate(
        const HealthInsuranceEstimateInput(annualPublicPensionIncome: 100000000),
      );

      expect(result.isFloorApplied, false);
      final monthlyPension = 100000000 / 12;
      final ratio = result.monthlyHealthInsurancePremium / monthlyPension;
      // 요율(7.19%) × 반영률(50%) = 3.595%
      expect(ratio, closeTo(healthInsuranceRate2026 * 0.5, 0.0005));
    });

    test('기타소득만 있을 때 월 건보료/월 기타소득 비율 ≈ 요율 100% (부과소득 커서 하한 미적용)', () {
      final result = HealthInsuranceEstimator.estimate(
        const HealthInsuranceEstimateInput(
          annualPublicPensionIncome: 0,
          annualOtherIncome: 100000000,
        ),
      );

      expect(result.isFloorApplied, false);
      final monthlyOther = 100000000 / 12;
      final ratio = result.monthlyHealthInsurancePremium / monthlyOther;
      expect(ratio, closeTo(healthInsuranceRate2026, 0.0005));
    });

    test('연 합계 = 월 합계 × 12 (모든 케이스 공통 불변식)', () {
      final cases = [
        const HealthInsuranceEstimateInput(annualPublicPensionIncome: 0),
        const HealthInsuranceEstimateInput(annualPublicPensionIncome: 12000000),
        const HealthInsuranceEstimateInput(
          annualPublicPensionIncome: 12000000,
          annualOtherIncome: 5000000,
        ),
        const HealthInsuranceEstimateInput(annualPublicPensionIncome: 100000000),
      ];

      for (final input in cases) {
        final result = HealthInsuranceEstimator.estimate(input);
        expect(result.annualTotalPremium, result.monthlyTotalPremium * 12);
      }
    });
  });

  group('estimate — 하한 경계 (TAX_RULES §8.4, 월 20,160원)', () {
    test('소득 0 → 하한 적용, 월 20,160원', () {
      final result = HealthInsuranceEstimator.estimate(
        const HealthInsuranceEstimateInput(annualPublicPensionIncome: 0),
      );

      expect(result.annualAssessedIncome, 0);
      expect(result.isFloorApplied, true);
      expect(result.monthlyHealthInsurancePremium, minHealthInsurancePremiumMonthly);
      expect(result.monthlyHealthInsurancePremium, 20160);
      // 장기요양 = 20,160 × 0.1314 = 2,649.024 → round 2,649
      expect(result.monthlyLtcPremium, 2649);
      expect(result.monthlyTotalPremium, 22809);
    });

    test('하한 바로 아래 (raw 계산값 20,154원) → 하한 20,160원으로 상향', () {
      // 기타소득 3,363,600원 → 월 부과소득 280,300원 × 0.0719 = 20,153.57 → round 20,154원 (<20,160)
      final result = HealthInsuranceEstimator.estimate(
        const HealthInsuranceEstimateInput(
          annualPublicPensionIncome: 0,
          annualOtherIncome: 3363600,
        ),
      );

      expect(result.isFloorApplied, true);
      expect(result.monthlyHealthInsurancePremium, 20160);
    });

    test('하한과 정확히 같은 raw 계산값(20,160원) → 하한 적용 아님(경계값 포함, 그대로 사용)', () {
      // 기타소득 3,364,668원 → 월 부과소득 280,389원 × 0.0719 = 20,159.9691 → round 20,160원 (== 하한)
      final result = HealthInsuranceEstimator.estimate(
        const HealthInsuranceEstimateInput(
          annualPublicPensionIncome: 0,
          annualOtherIncome: 3364668,
        ),
      );

      expect(result.isFloorApplied, false);
      expect(result.monthlyHealthInsurancePremium, 20160);
    });

    test('하한 바로 위 (raw 계산값 20,161원) → 하한 미적용, raw 값 그대로 사용', () {
      // 기타소득 3,364,800원 → 월 부과소득 280,400원 × 0.0719 = 20,160.76 → round 20,161원 (>20,160)
      final result = HealthInsuranceEstimator.estimate(
        const HealthInsuranceEstimateInput(
          annualPublicPensionIncome: 0,
          annualOtherIncome: 3364800,
        ),
      );

      expect(result.isFloorApplied, false);
      expect(result.monthlyHealthInsurancePremium, 20161);
      expect(result.monthlyTotalPremium, 22810);
      expect(result.annualTotalPremium, 273720);
    });
  });

  group('checkDependentEligibility — 피부양자 자격 판정 (TAX_RULES §8.6, 소득 기준만)', () {
    test('공적연금 1,999만원 → 자격 유지 (2,000만원 경계 미만)', () {
      final result = HealthInsuranceEstimator.checkDependentEligibility(
        const HealthInsuranceEstimateInput(annualPublicPensionIncome: 19990000),
      );

      expect(result.combinedAnnualIncome, 19990000);
      expect(result.dependentDisqualified, false);
    });

    test('공적연금 정확히 2,000만원 → 자격 유지 ("초과" 조건이므로 경계값 포함 안 됨)', () {
      final result = HealthInsuranceEstimator.checkDependentEligibility(
        const HealthInsuranceEstimateInput(
          annualPublicPensionIncome: dependentDisqualifyIncomeThreshold,
        ),
      );

      expect(result.combinedAnnualIncome, 20000000);
      expect(result.dependentDisqualified, false);
    });

    test('공적연금 2,001만원 → 자격 상실 (2,000만원 초과)', () {
      final result = HealthInsuranceEstimator.checkDependentEligibility(
        const HealthInsuranceEstimateInput(annualPublicPensionIncome: 20010000),
      );

      expect(result.combinedAnnualIncome, 20010000);
      expect(result.dependentDisqualified, true);
    });

    test('공적연금 + 기타소득 합산 후 2,000만원 초과 시 자격 상실', () {
      final result = HealthInsuranceEstimator.checkDependentEligibility(
        const HealthInsuranceEstimateInput(
          annualPublicPensionIncome: 15000000,
          annualOtherIncome: 6000000,
        ),
      );

      expect(result.combinedAnnualIncome, 21000000);
      expect(result.dependentDisqualified, true);
    });

    test('피부양자 판정(공적연금 100%)과 부과 계산(공적연금 50%) 반영률 차이 명시 검증', () {
      // 동일 입력값(공적연금 3,000만원)에 대해:
      // - 부과 대상 소득(estimate) = 30,000,000 × 50% = 15,000,000
      // - 피부양자 판정 합산소득(checkDependentEligibility) = 30,000,000 × 100% = 30,000,000
      const input = HealthInsuranceEstimateInput(annualPublicPensionIncome: 30000000);

      final premiumResult = HealthInsuranceEstimator.estimate(input);
      final dependentResult = HealthInsuranceEstimator.checkDependentEligibility(input);

      expect(premiumResult.annualAssessedIncome, 15000000);
      expect(dependentResult.combinedAnnualIncome, 30000000);
      // 피부양자 판정 소득이 부과 대상 소득의 정확히 2배 (100% ÷ 50%)
      expect(dependentResult.combinedAnnualIncome, premiumResult.annualAssessedIncome * 2);
      // 부과 대상 소득은 2,000만원 미만이라 피부양자 판정만으로 걸러지는 케이스임을 확인
      expect(premiumResult.annualAssessedIncome < dependentDisqualifyIncomeThreshold, true);
      expect(dependentResult.dependentDisqualified, true);
    });
  });

  group('isEstimate 플래그 (간이 추정 구분용)', () {
    test('모든 입력 조합에서 isEstimate = true', () {
      final zeroIncome = HealthInsuranceEstimator.estimate(
        const HealthInsuranceEstimateInput(annualPublicPensionIncome: 0),
      );
      final withIncome = HealthInsuranceEstimator.estimate(
        const HealthInsuranceEstimateInput(
          annualPublicPensionIncome: 12000000,
          annualOtherIncome: 5000000,
        ),
      );

      expect(zeroIncome.isEstimate, true);
      expect(withIncome.isEstimate, true);
    });
  });
}
