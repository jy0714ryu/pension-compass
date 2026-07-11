import 'package:flutter_test/flutter_test.dart';
import 'package:pension_compass/services/nps_estimator.dart';

void main() {
  group('normalStartAgeFor — 출생연도별 수급개시연령 (TAX_RULES §7.3)', () {
    test('1952년 이전 → 60세', () {
      expect(NpsEstimator.normalStartAgeFor(1950), 60);
      expect(NpsEstimator.normalStartAgeFor(1952), 60);
    });

    test('1953~1956년 → 61세', () {
      expect(NpsEstimator.normalStartAgeFor(1953), 61);
      expect(NpsEstimator.normalStartAgeFor(1956), 61);
    });

    test('1957~1960년 → 62세', () {
      expect(NpsEstimator.normalStartAgeFor(1957), 62);
      expect(NpsEstimator.normalStartAgeFor(1960), 62);
    });

    test('1961~1964년 → 63세', () {
      expect(NpsEstimator.normalStartAgeFor(1961), 63);
      expect(NpsEstimator.normalStartAgeFor(1964), 63);
    });

    test('1965~1968년 → 64세', () {
      expect(NpsEstimator.normalStartAgeFor(1965), 64);
      expect(NpsEstimator.normalStartAgeFor(1968), 64);
    });

    test('1969년 이후 → 65세', () {
      expect(NpsEstimator.normalStartAgeFor(1969), 65);
      expect(NpsEstimator.normalStartAgeFor(1990), 65);
    });
  });

  group('estimate — 산식 손계산 검증 (TAX_RULES §7.1)', () {
    // 공통 산식: 기본연금액 = 1.290 × (A값 + B값) × [1 + 0.05×(가입월수-240)/12]
    // A값 = 3,193,511원 (2026년 고시)

    test('월소득 300만·가입 20년(240개월)·정상수령 → 계수 1.0', () {
      // 계수 = 1 + 0.05×(240-240)/12 = 1.0
      // 기본연금액 = 1.290 × (3,193,511 + 3,000,000) × 1.0
      //            = 1.290 × 6,193,511 = 7,989,629.19 → round 7,989,629
      final result = NpsEstimator.estimate(const NpsEstimateInput(
        monthlyIncome: 3000000,
        enrollmentMonths: 240,
        birthYear: 1970,
        receiptType: NpsReceiptType.normal,
      ));

      expect(result.eligibility, NpsEligibility.eligible);
      expect(result.monthlyPensionAmount, 7989629);
      expect(result.normalStartAge, 65);
      expect(result.actualStartAge, 65);
      expect(result.adjustmentRate, 0);
      expect(result.appliedOffsetYears, 0);
      expect(result.isEstimate, true);
    });

    test('월소득 500만·가입 30년(360개월)·정상수령 → 20년 초과 가산 계수 1.5', () {
      // 계수 = 1 + 0.05×(360-240)/12 = 1 + 0.5 = 1.5
      // 기본연금액 = 1.290 × (3,193,511 + 5,000,000) × 1.5
      //            = 1.290 × 8,193,511 × 1.5 = 15,854,443.785 → round 15,854,444
      final result = NpsEstimator.estimate(const NpsEstimateInput(
        monthlyIncome: 5000000,
        enrollmentMonths: 360,
        birthYear: 1958,
        receiptType: NpsReceiptType.normal,
      ));

      expect(result.monthlyPensionAmount, 15854444);
      expect(result.normalStartAge, 62);
    });

    test('월소득 200만·가입 15년(180개월)·정상수령 → 20년 미만 감액 계수 0.75', () {
      // 계수 = 1 + 0.05×(180-240)/12 = 1 - 0.25 = 0.75
      // 기본연금액 = 1.290 × (3,193,511 + 2,000,000) × 0.75
      //            = 1.290 × 5,193,511 × 0.75 = 5,024,721.8925 → round 5,024,722
      final result = NpsEstimator.estimate(const NpsEstimateInput(
        monthlyIncome: 2000000,
        enrollmentMonths: 180,
        birthYear: 1975,
        receiptType: NpsReceiptType.normal,
      ));

      expect(result.eligibility, NpsEligibility.eligible);
      expect(result.monthlyPensionAmount, 5024722);
    });
  });

  group('estimate — 경계 처리', () {
    test('가입 10년 미만(119개월) → 수급 불가', () {
      final result = NpsEstimator.estimate(const NpsEstimateInput(
        monthlyIncome: 3000000,
        enrollmentMonths: 119,
        birthYear: 1970,
        receiptType: NpsReceiptType.normal,
      ));

      expect(result.eligibility, NpsEligibility.ineligibleShortEnrollment);
      expect(result.isEligible, false);
      expect(result.monthlyPensionAmount, 0);
    });

    test('가입 정확히 10년(120개월) → 수급 가능 (경계값 포함)', () {
      final result = NpsEstimator.estimate(const NpsEstimateInput(
        monthlyIncome: 3000000,
        enrollmentMonths: 120,
        birthYear: 1970,
        receiptType: NpsReceiptType.normal,
      ));

      // 계수 = 1 + 0.05×(120-240)/12 = 1 - 0.5 = 0.5
      // 기본연금액 = 1.290 × 6,193,511 × 0.5 = 3,994,814.595 → round 3,994,815
      expect(result.eligibility, NpsEligibility.eligible);
      expect(result.monthlyPensionAmount, 3994815);
    });

    test('월소득이 상한(6,590,000원) 초과 시 상한으로 클램프', () {
      final result = NpsEstimator.estimate(const NpsEstimateInput(
        monthlyIncome: 10000000,
        enrollmentMonths: 240,
        birthYear: 1970,
        receiptType: NpsReceiptType.normal,
      ));

      // 기본연금액 = 1.290 × (3,193,511 + 6,590,000) × 1.0 = 12,620,729.19 → round 12,620,729
      expect(result.clampedMonthlyIncome, npsIncomeCeiling);
      expect(result.monthlyPensionAmount, 12620729);
    });

    test('월소득이 하한(410,000원) 미만 시 하한으로 클램프', () {
      final result = NpsEstimator.estimate(const NpsEstimateInput(
        monthlyIncome: 100000,
        enrollmentMonths: 240,
        birthYear: 1970,
        receiptType: NpsReceiptType.normal,
      ));

      // 기본연금액 = 1.290 × (3,193,511 + 410,000) × 1.0 = 4,648,529.19 → round 4,648,529
      expect(result.clampedMonthlyIncome, npsIncomeFloor);
      expect(result.monthlyPensionAmount, 4648529);
    });

    test('조기 5년 → 최대 30% 감액, 개시연령 -5세', () {
      // 계수(300개월) = 1 + 0.05×(300-240)/12 = 1.25
      // 기본연금액 = 1.290 × (3,193,511 + 4,000,000) × 1.25
      //            = 1.290 × 7,193,511 × 1.25 = 11,599,536.4875 → round 11,599,536
      // 감액 -30% → round(11,599,536 × 0.7) = round(8,119,675.2) = 8,119,675
      final result = NpsEstimator.estimate(const NpsEstimateInput(
        monthlyIncome: 4000000,
        enrollmentMonths: 300,
        birthYear: 1958, // 정상 62세
        receiptType: NpsReceiptType.early,
        offsetYears: 5,
      ));

      expect(result.appliedOffsetYears, 5);
      expect(result.adjustmentRate, closeTo(-0.30, 1e-9));
      expect(result.actualStartAge, 57); // 62 - 5, 최소 조기연령(57)과 정확히 일치
      expect(result.monthlyPensionAmount, 8119675);
    });

    test('조기 입력 7년 → 최대 5년으로 클램프 (최대 30% 감액 초과 불가)', () {
      final result = NpsEstimator.estimate(const NpsEstimateInput(
        monthlyIncome: 4000000,
        enrollmentMonths: 300,
        birthYear: 1958,
        receiptType: NpsReceiptType.early,
        offsetYears: 7,
      ));

      expect(result.appliedOffsetYears, 5);
      expect(result.adjustmentRate, closeTo(-0.30, 1e-9));
    });

    test('연기 5년 → 최대 36% 증액, 개시연령 +5세', () {
      // 계수(252개월) = 1 + 0.05×(252-240)/12 = 1.05
      // 기본연금액 = 1.290 × (3,193,511 + 3,500,000) × 1.05
      //            = 1.290 × 6,693,511 × 1.05 = 9,066,360.6495 → round 9,066,361
      // 증액 +36% → round(9,066,361 × 1.36) = round(12,330,250.96) = 12,330,251
      final result = NpsEstimator.estimate(const NpsEstimateInput(
        monthlyIncome: 3500000,
        enrollmentMonths: 252,
        birthYear: 1963, // 정상 63세
        receiptType: NpsReceiptType.deferred,
        offsetYears: 5,
      ));

      expect(result.appliedOffsetYears, 5);
      expect(result.adjustmentRate, closeTo(0.36, 1e-9));
      expect(result.actualStartAge, 68); // 63 + 5
      expect(result.monthlyPensionAmount, 12330251);
    });

    test('연기 입력 9년 → 최대 5년으로 클램프 (최대 36% 증액 초과 불가)', () {
      final result = NpsEstimator.estimate(const NpsEstimateInput(
        monthlyIncome: 3500000,
        enrollmentMonths: 252,
        birthYear: 1963,
        receiptType: NpsReceiptType.deferred,
        offsetYears: 9,
      ));

      expect(result.appliedOffsetYears, 5);
      expect(result.adjustmentRate, closeTo(0.36, 1e-9));
    });

    test('정상수령은 offsetYears 입력값과 무관하게 0으로 처리', () {
      final result = NpsEstimator.estimate(const NpsEstimateInput(
        monthlyIncome: 3000000,
        enrollmentMonths: 240,
        birthYear: 1970,
        receiptType: NpsReceiptType.normal,
        offsetYears: 5, // 무시되어야 함
      ));

      expect(result.appliedOffsetYears, 0);
      expect(result.adjustmentRate, 0);
      expect(result.actualStartAge, result.normalStartAge);
    });
  });

  group('isEstimate 플래그 (간이 추정 구분용)', () {
    test('수급 가능·불가 케이스 모두 isEstimate = true', () {
      final eligible = NpsEstimator.estimate(const NpsEstimateInput(
        monthlyIncome: 3000000,
        enrollmentMonths: 240,
        birthYear: 1970,
        receiptType: NpsReceiptType.normal,
      ));
      final ineligible = NpsEstimator.estimate(const NpsEstimateInput(
        monthlyIncome: 3000000,
        enrollmentMonths: 60,
        birthYear: 1970,
        receiptType: NpsReceiptType.normal,
      ));

      expect(eligible.isEstimate, true);
      expect(ineligible.isEstimate, true);
    });
  });
}
