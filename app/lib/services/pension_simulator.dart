import '../models/simulation_result.dart';
import 'tax_calculator.dart';

/// 사적연금 과세재원 저율 분리과세 연간 한도 (원)
/// 수령한도 내 인정액 합계가 이를 초과하면 그 해 인정액 전액 16.5% (절벽)
const int kAnnualPensionBracket = 15000000;

/// 퇴직소득세 실효세율 가정 (근속연수·금액별 편차가 커 5% 고정 가정 — UI에 명시)
const double kRetirementEffectiveRate = 0.05;

/// 기타소득세율 (절벽·수령한도 초과)
const double kPenaltyRate = 0.165;

/// 1,500만원 절벽 판정 대상 (사적연금 과세재원)
const Set<WithdrawalSource> kBracketSources = {
  WithdrawalSource.pensionDeducted,
  WithdrawalSource.irpSelf,
  WithdrawalSource.earnings,
};

/// 연금수령한도 소진 대상 (과세제외금액·ISA는 한도 미적용 — 소득세법 시행령 40조의3)
const Set<WithdrawalSource> kPayoutLimitedSources = {
  WithdrawalSource.pensionDeducted,
  WithdrawalSource.irpSelf,
  WithdrawalSource.earnings,
  WithdrawalSource.irpRetirement,
};

/// 연간 인출 원장 항목 — 수령한도 내(within)/초과(over) 분리 기록
class DrawSplit {
  int within = 0;
  int over = 0;
  int get total => within + over;
}

/// 연금 인출 시뮬레이션 엔진
class PensionSimulator {
  PensionSimulator._();

  /// 연금수령한도: 연차 1~10년 = 연초 연금계좌 평가액(ISA 제외) / (11-연차) × 1.2
  /// 연차 11년+ 무제한. ×1.2 는 정수 연산 (평가액×12 ÷ ((11-연차)×10)).
  static int payoutLimitFor(Map<WithdrawalSource, int> pools, int year) {
    if (year >= 11) return 1 << 60;
    final base = (pools[WithdrawalSource.pensionNonDeducted] ?? 0) +
        (pools[WithdrawalSource.pensionDeducted] ?? 0) +
        (pools[WithdrawalSource.irpSelf] ?? 0) +
        (pools[WithdrawalSource.earnings] ?? 0) +
        (pools[WithdrawalSource.irpRetirement] ?? 0);
    return (base * 12) ~/ ((11 - year) * 10);
  }

  /// 연말 세금 확정 — 절벽·수령한도 초과·퇴직세 감면을 연간 합산 기준으로 일괄 판정
  static List<WithdrawalDetail> finalizeYearTax(
    Map<WithdrawalSource, DrawSplit> ledger,
    int age,
    int year,
  ) {
    final details = <WithdrawalDetail>[];

    // 1) 비과세 소스
    for (final src in const [
      WithdrawalSource.isaProfit,
      WithdrawalSource.isaPrincipal,
      WithdrawalSource.pensionNonDeducted,
    ]) {
      final split = ledger[src];
      if (split == null || split.total <= 0) continue;
      details.add(WithdrawalDetail(
        source: src, amount: split.total, tax: 0, taxRate: 0));
    }

    // 2) 사적연금 과세재원 — 절벽 판정 (수령한도 내 인정액 합계 기준)
    final recognized = kBracketSources.fold<int>(
        0, (sum, src) => sum + (ledger[src]?.within ?? 0));
    final cliff = recognized > kAnnualPensionBracket;
    final withinRate =
        cliff ? kPenaltyRate : TaxCalculator.getPensionTaxRate(age);
    for (final src in kBracketSources) {
      final split = ledger[src];
      if (split == null) continue;
      if (split.within > 0) {
        details.add(WithdrawalDetail(
          source: src,
          amount: split.within,
          tax: (split.within * withinRate).round(),
          taxRate: withinRate * 100,
        ));
      }
      if (split.over > 0) {
        // 수령한도 초과 = 연금외수령 → 기타소득세 16.5%
        details.add(WithdrawalDetail(
          source: src,
          amount: split.over,
          tax: (split.over * kPenaltyRate).round(),
          taxRate: kPenaltyRate * 100,
        ));
      }
    }

    // 3) 퇴직금 재원 — 한도 내 30% 감면(11년차부터 40%), 한도 초과 시 감면 없음
    final ret = ledger[WithdrawalSource.irpRetirement];
    if (ret != null) {
      final reduction = year <= 10 ? 0.7 : 0.6;
      if (ret.within > 0) {
        final rate = kRetirementEffectiveRate * reduction;
        details.add(WithdrawalDetail(
          source: WithdrawalSource.irpRetirement,
          amount: ret.within,
          tax: (ret.within * rate).round(),
          taxRate: rate * 100,
        ));
      }
      if (ret.over > 0) {
        details.add(WithdrawalDetail(
          source: WithdrawalSource.irpRetirement,
          amount: ret.over,
          tax: (ret.over * kRetirementEffectiveRate).round(),
          taxRate: kRetirementEffectiveRate * 100,
        ));
      }
    }

    return details;
  }
}
