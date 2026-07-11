/// 지역가입자 건강보험료(소득 기준) 추정 서비스
///
/// ⚠️ 소득 기준 부과분만 추정한다 — 재산(부동산 등)·자동차 기준 부과분은
/// 스코프 외(P1 보류, exec-plan②). 실제 지역가입자 건보료는 소득분 + 재산분으로
/// 구성되므로 이 결과는 항상 실제 고지액보다 낮게 나온다.
///
/// ★ [★ 킬러 팩트, TAX_RULES.md §8.1] 현재(2026년) 기준 연금저축·IRP 등
/// **사적연금** 인출은 건강보험료 부과 대상 소득에 포함되지 않는다. 부과 대상은
/// 국민연금·공무원연금 등 **5대 공적연금소득뿐**이다 — 그래서 이 서비스의 입력에는
/// 사적연금 파라미터 자체가 없다(구조적으로 부과 대상이 아님을 드러냄). 단, 법적
/// 불확실성이 있어 제도 변경 가능성을 배제하지 않는다(감사원 지적·개정안 계류 중).
///
/// 근거: docs/TAX_RULES.md §8 건강보험료 (v1.1 Task 1 검증 + Task 4 요율 재확인)
library;

/// 건강보험료율 (2026년, 보건복지부 고시)
/// 직장가입자·지역가입자 소득 정률분 동일 요율. 지역가입자는 전액 본인 부담.
/// 재확인 완료(Task 4, 2026-07-11): "월 소득 × 7.19%" 보건복지부 보도자료 명시.
const double healthInsuranceRate2026 = 0.0719;

/// 장기요양보험료율 — 건강보험료액 대비 비율 (2026년, 보건복지부 고시)
/// 월 장기요양보험료 = 월 건강보험료 × 이 비율
const double ltcInsuranceRateOnPremium2026 = 0.1314;

/// 공적연금소득의 건보료 부과 대상 소득 반영률 (지역가입자 정률제)
/// 예: 국민연금 연 1,200만원 → 부과 대상 소득 산입액 600만원
const double publicPensionAssessmentReflectionRate = 0.50;

/// 기타소득(이자·배당 등)의 건보료 부과 대상 소득 반영률 — 100% 전액 반영
const double otherIncomeAssessmentReflectionRate = 1.00;

/// 공적연금소득의 **피부양자 자격 판정** 시 소득 반영률 — 전액(100%) 반영
///
/// ⚠️ 부과 대상 소득 산정(50%, [publicPensionAssessmentReflectionRate])과
/// 피부양자 판정(100%)의 공적연금 반영률이 다르다. 혼동 주의 — TAX_RULES.md §8.2·8.6.
const double publicPensionDependentReflectionRate = 1.00;

/// 월 건강보험료 하한액 (원, 2026년 고시) — 직장·지역 동일
const int minHealthInsurancePremiumMonthly = 20160;

/// 피부양자 자격 상실 소득 기준 (원/년) — 이 금액 초과 시 자격 상실
/// (재산 기준은 별도, 이 서비스는 소득 기준만 판정)
const int dependentDisqualifyIncomeThreshold = 20000000;

/// 지역가입자 건강보험료 추정 입력값
class HealthInsuranceEstimateInput {
  /// 연간 공적연금소득 (원) — 국민연금 등 5대 공적연금 연 수령액
  final int annualPublicPensionIncome;

  /// 연간 기타소득 (원) — 이자·배당 등 100% 반영분. 기본값 0
  final int annualOtherIncome;

  const HealthInsuranceEstimateInput({
    required this.annualPublicPensionIncome,
    this.annualOtherIncome = 0,
  });
}

/// 지역가입자 건강보험료 추정 결과
class HealthInsuranceEstimateResult {
  /// 간이 추정 여부 — 항상 true (재산분 미반영·소득 기준 추정치임을 구분)
  final bool isEstimate = true;

  /// 부과 대상 소득 (원/년) = 공적연금소득×50% + 기타소득×100%
  final int annualAssessedIncome;

  /// 월 건강보험료 (원) — 하한 적용 후 값
  final int monthlyHealthInsurancePremium;

  /// 월 장기요양보험료 (원) = 월 건강보험료 × 13.14%
  final int monthlyLtcPremium;

  /// 월 합계 (원) = 월 건강보험료 + 월 장기요양보험료
  final int monthlyTotalPremium;

  /// 연 합계 (원) = 월 합계 × 12
  final int annualTotalPremium;

  /// 하한액이 적용되었는지 여부 (합산 전 건강보험료 기준)
  final bool isFloorApplied;

  /// 적용된 건강보험료율
  final double appliedHealthInsuranceRate;

  /// 적용된 장기요양보험료율 (건보료 대비)
  final double appliedLtcRate;

  const HealthInsuranceEstimateResult({
    required this.annualAssessedIncome,
    required this.monthlyHealthInsurancePremium,
    required this.monthlyLtcPremium,
    required this.monthlyTotalPremium,
    required this.annualTotalPremium,
    required this.isFloorApplied,
    required this.appliedHealthInsuranceRate,
    required this.appliedLtcRate,
  });
}

/// 피부양자 자격 판정 결과 (소득 기준만, 재산 기준은 스코프 외)
class DependentEligibilityResult {
  /// 판정에 사용된 합산소득 (원/년) = 공적연금소득×100% + 기타소득×100%
  /// (부과 대상 소득 계산의 50% 반영률과 다름 — §8.2·8.6 참조)
  final int combinedAnnualIncome;

  /// 소득 기준 2,000만원 초과로 피부양자 자격 상실 여부
  final bool dependentDisqualified;

  const DependentEligibilityResult({
    required this.combinedAnnualIncome,
    required this.dependentDisqualified,
  });
}

/// 지역가입자 건강보험료(소득 기준) 추정 계산기
class HealthInsuranceEstimator {
  HealthInsuranceEstimator._();

  /// 건강보험료·장기요양보험료 추정 실행
  ///
  /// 산식 (TAX_RULES.md §8.2~8.4):
  /// 1. 부과 대상 소득(연) = 공적연금소득 × 50% + 기타소득 × 100%
  /// 2. 월 건강보험료(raw) = 부과 대상 소득 ÷ 12 × 7.19%
  /// 3. 하한 적용: raw < 20,160원이면 20,160원으로 (합산 전 기준, §8.4)
  /// 4. 월 장기요양보험료 = 월 건강보험료(하한 적용 후) × 13.14%
  static HealthInsuranceEstimateResult estimate(
    HealthInsuranceEstimateInput input,
  ) {
    final assessedIncome = (input.annualPublicPensionIncome *
                publicPensionAssessmentReflectionRate +
            input.annualOtherIncome * otherIncomeAssessmentReflectionRate)
        .round();

    final rawMonthlyHealthPremium =
        (assessedIncome / 12) * healthInsuranceRate2026;
    final roundedRawPremium = rawMonthlyHealthPremium.round();

    final isFloorApplied =
        roundedRawPremium < minHealthInsurancePremiumMonthly;
    final monthlyHealthInsurancePremium =
        isFloorApplied ? minHealthInsurancePremiumMonthly : roundedRawPremium;

    final monthlyLtcPremium =
        (monthlyHealthInsurancePremium * ltcInsuranceRateOnPremium2026)
            .round();

    final monthlyTotalPremium =
        monthlyHealthInsurancePremium + monthlyLtcPremium;

    return HealthInsuranceEstimateResult(
      annualAssessedIncome: assessedIncome,
      monthlyHealthInsurancePremium: monthlyHealthInsurancePremium,
      monthlyLtcPremium: monthlyLtcPremium,
      monthlyTotalPremium: monthlyTotalPremium,
      annualTotalPremium: monthlyTotalPremium * 12,
      isFloorApplied: isFloorApplied,
      appliedHealthInsuranceRate: healthInsuranceRate2026,
      appliedLtcRate: ltcInsuranceRateOnPremium2026,
    );
  }

  /// 피부양자 자격 판정 (소득 기준만, TAX_RULES.md §8.6)
  ///
  /// ⚠️ 공적연금소득은 [estimate]의 부과 대상 소득 계산(50% 반영)과 달리
  /// **100% 전액 반영**한다. 재산 기준(재산세 과세표준 9억원 초과 등)은
  /// 이 서비스의 스코프 외 — 소득 기준만 판정한다.
  static DependentEligibilityResult checkDependentEligibility(
    HealthInsuranceEstimateInput input,
  ) {
    final combinedIncome = (input.annualPublicPensionIncome *
                publicPensionDependentReflectionRate +
            input.annualOtherIncome * otherIncomeAssessmentReflectionRate)
        .round();

    return DependentEligibilityResult(
      combinedAnnualIncome: combinedIncome,
      dependentDisqualified:
          combinedIncome > dependentDisqualifyIncomeThreshold,
    );
  }
}
