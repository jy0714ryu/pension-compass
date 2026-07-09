# WithdrawalOptimizer v2 — 복리·절벽·수령한도·전략 토너먼트 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 인출 시뮬레이터를 "복리 성장 + 1,500만원 절벽 회피 + 연금수령한도(10년 룰) + 4-전략 토너먼트" 구조의 다이내믹 엔진으로 리팩토링한다.

**Architecture:** 전략(인출 순서 정책)과 엔진(연 단위 시뮬레이션·연말 세금 확정)을 분리한다. 4개 후보 전략을 동일 엔진으로 전부 시뮬레이션한 뒤 세금 부담(낸 세금+잠재세)이 최소인 전략을 우승자로 선택한다. 세금은 인출 시점이 아닌 **연말 원장(ledger) 일괄 확정** 방식 — 절벽·수령한도 초과 판정이 연간 합산 기준이기 때문.

**Tech Stack:** Flutter/Dart, Riverpod, flutter_test. 외부 패키지 추가 없음.

## Global Constraints (세법 스펙 v2 — 모든 Task 공통)

- **금액은 전부 `int` 원 단위.** `double` 금액 연산 금지 (세율 곱 직후 `.round()`로 즉시 int 복귀).
- **연금소득세율(지방세 포함):** 55~69세 5.5%, 70~79세 4.4%, 80세+ 3.3%.
- **1,500만원 절벽:** 사적연금 과세재원(공제분+IRP자기납입분+운용수익)의 연간 **수령한도 내 인정액 합계**가 15,000,000원 초과 시, 그 해 인정액 **전액** 16.5% (분리과세 선택 가정). 초과분만이 아님.
- **연금수령한도(10년 룰):** 연차 1~10년 = 연초 연금계좌 평가액(ISA 제외) ÷ (11−연차) × 1.2. 연차 11+ 무제한. 한도 소진 대상 = 과세재원+퇴직금분 인출만 (비공제분·ISA는 자유 인출). 한도 초과 인출: 과세재원 → 16.5% 기타소득세, 퇴직금분 → 퇴직소득세 감면 없음.
- **퇴직소득세:** 실효세율 5% 고정 가정(상수). 한도 내 수령 시 연차 1~10년 ×0.7 (=3.5%), 11년차+ ×0.6 (=3.0%), 한도 초과 ×1.0.
- **복리 성장:** 연말(그 해 인출 후) 각 풀 잔액 × `expectedReturnRate`, **전액 `earnings`(운용수익) 풀로 편입** (운용수익은 세법상 과세재원).
- **우승 판정:** `taxBurden = totalTax + latentTax` 최소. 동률 시 전략 리스트 앞선 것. `latentTax` = 기말 과세재원 잔액×기말나이 저율 + 퇴직금 잔액×3.5% (근사, 주석 명시).
- **절감액 비교 기준(baseline)은 `pension_first` 전략 고정** (결과 화면 "기존 방식 = 연금저축부터" 설명과 일치).
- 모든 커밋 전 `flutter test` 통과. 작업 디렉토리: `app/`.
- MVP 명시 가정(코드 주석+UI 문구로 방어): 종합과세 선택 미반영(16.5% 보수 가정), ISA는 연금계좌 평가액에서 제외(보수적), 2013.3.1 이전 가입 특례(연차 6부터) 미반영, 수령연차=시뮬레이션 연차 가정.

## File Structure

| 파일 | 작업 | 책임 |
|---|---|---|
| `app/lib/models/pension_input.dart` | Modify | `expectedReturnRate` 필드 추가 |
| `app/lib/models/simulation_result.dart` | Modify | `WithdrawalSource.earnings` 추가, `StrategyOutcome` 신규, `SimulationResult` 확장 |
| `app/lib/services/withdrawal_strategies.dart` | Create | `DrawStep` + 4개 전략 정의 (순수 데이터) |
| `app/lib/services/pension_simulator.dart` | Create | 시뮬레이션 엔진: 수령한도 공식, 연말 세금 확정, 연 루프·성장 |
| `app/lib/services/withdrawal_optimizer.dart` | Rewrite | 토너먼트 오케스트레이션 (기존 `optimize()` API 유지) |
| `app/lib/services/tax_calculator.dart` | 유지 | `getPensionTaxRate` 재사용 (변경 없음) |
| `app/lib/services/local_storage_service.dart` | Modify | `expectedReturnRate` 저장/로드 |
| `app/lib/providers/pension_provider.dart` | Modify | `updateExpectedReturnRate` 추가 |
| `app/lib/screens/home_screen.dart` | Modify | 수익률 입력 스텝퍼 |
| `app/lib/screens/result_screen.dart` | Modify | earnings 케이스, 실제 baseline 차트, 가정 안내 팁 |
| `app/test/services/pension_simulator_test.dart` | Create | 세금 확정·한도 공식·엔진 테스트 |
| `app/test/services/withdrawal_optimizer_test.dart` | Create | 토너먼트 통합 테스트 |
| `docs/ALGORITHM.md` | Modify | v2 알고리즘 문서화 |

---

### Task 1: 브랜치 생성 + 모델 확장

**Files:**
- Modify: `app/lib/models/pension_input.dart`
- Modify: `app/lib/models/simulation_result.dart`
- Modify: `app/lib/screens/result_screen.dart` (enum 케이스 추가만 — 컴파일 유지 목적)

**Interfaces:**
- Produces: `PensionInput.expectedReturnRate` (double, 기본 0.04), `WithdrawalSource.earnings`, `StrategyOutcome` 클래스, `SimulationResult`의 신규 optional 필드 `outcomes`/`optimalStrategyId`/`optimalStrategyName`/`baselineSchedule` + getter `cumulativeTaxBaseline`

- [ ] **Step 1: 브랜치 생성**

```bash
cd /Users/jechangryu/Workspace/pension-compass && git checkout -b feat/optimizer-v2
```

- [ ] **Step 2: `pension_input.dart`에 `expectedReturnRate` 추가**

필드 선언부(`incomeLevel` 아래)에 추가:

```dart
  /// 예상 연평균 운용 수익률 (복리, 예: 0.04 = 4%)
  final double expectedReturnRate;
```

생성자에 `this.expectedReturnRate = 0.04,` 추가. `isValid`에 조건 추가:

```dart
        expectedReturnRate >= 0 &&
        expectedReturnRate <= 0.20 &&
```

`copyWith`에 파라미터 `double? expectedReturnRate`와 본문 `expectedReturnRate: expectedReturnRate ?? this.expectedReturnRate,` 추가. `example()`/`empty()` factory에는 명시적으로 `expectedReturnRate: 0.04,` 추가.

- [ ] **Step 3: `simulation_result.dart`에 `earnings` 소스 추가**

`WithdrawalSource` enum의 `pensionDeducted` 항목 뒤에 추가:

```dart
  /// 운용수익 (시뮬레이션 중 발생한 복리 수익 — 과세재원, 3.3~5.5%)
  earnings('운용수익', '연금소득세'),
```

`baseTaxRate` switch에 `case WithdrawalSource.earnings:` → `pensionDeducted`와 같은 5.5 그룹에, `priority` switch에 `case WithdrawalSource.earnings: return 5;` 추가 (irpSelf=5를 6으로, irpRetirement를 7로 밀어도 무방 — 값 자체는 UI 미사용).

- [ ] **Step 4: `simulation_result.dart`에 `StrategyOutcome` 추가 + `SimulationResult` 확장**

파일 하단에 추가:

```dart
/// 단일 전략 시뮬레이션 결과 (토너먼트 참가자)
class StrategyOutcome {
  final String strategyId;
  final String strategyName;
  final List<YearlyWithdrawal> schedule;
  final int totalTax;
  final int totalWithdrawn;
  final int finalBalance;
  final int latentTax; // 기말 잔액에 대한 잠재 세금 (근사)

  const StrategyOutcome({
    required this.strategyId,
    required this.strategyName,
    required this.schedule,
    required this.totalTax,
    required this.totalWithdrawn,
    required this.finalBalance,
    required this.latentTax,
  });

  /// 우승 판정 지표: 낸 세금 + 잠재 세금 (낮을수록 우승)
  int get taxBurden => totalTax + latentTax;

  /// 순자산 (참고): 순수령액 + 기말잔액 - 잠재세
  int get netWealth => totalWithdrawn - totalTax + finalBalance - latentTax;
}
```

`SimulationResult`에 optional 필드 추가 (기존 생성자 호출부 호환):

```dart
  /// 토너먼트 전체 결과 (전략 비교용)
  final List<StrategyOutcome> outcomes;

  /// 우승 전략 id / 표시명
  final String optimalStrategyId;
  final String optimalStrategyName;

  /// 기존 방식(baseline) 연도별 스케줄 — 차트 실데이터용
  final List<YearlyWithdrawal> baselineSchedule;
```

생성자에 `this.outcomes = const [], this.optimalStrategyId = '', this.optimalStrategyName = '', this.baselineSchedule = const [],` 추가. getter 추가:

```dart
  /// 연도별 누적 세금 (기존 방식) — baselineSchedule 기반 실데이터
  List<int> get cumulativeTaxBaseline {
    final result = <int>[];
    int cumulative = 0;
    for (final year in baselineSchedule) {
      cumulative += year.totalTax;
      result.add(cumulative);
    }
    return result;
  }
```

- [ ] **Step 5: `result_screen.dart` switch에 earnings 케이스 추가 (컴파일 유지)**

`_getBadgeColor`: `case WithdrawalSource.pensionDeducted:` 그룹에 `case WithdrawalSource.earnings:` 추가 (→ `AppColors.info`). `_getTaxLabel`: 같은 그룹에 추가 (→ `'분리과세'`).

- [ ] **Step 6: 컴파일·기존 테스트 확인**

Run: `cd app && flutter analyze && flutter test`
Expected: analyze 에러 0. (withdrawal_optimizer.dart가 아직 구 로직이지만 enum 추가는 non-exhaustive switch 에러를 내지 않는지 확인 — `_getTaxRate`의 switch가 exhaustive라 에러 발생 시 `case WithdrawalSource.earnings:`를 `pensionDeducted` 그룹에 임시 추가)

- [ ] **Step 7: Commit**

```bash
git add -A && git commit -m "feat: 모델 확장 — expectedReturnRate, earnings 풀, StrategyOutcome"
```

---

### Task 2: 시뮬레이터 코어 — 수령한도 공식 + 연말 세금 확정 (TDD)

**Files:**
- Create: `app/lib/services/pension_simulator.dart` (이 Task에서는 상수·`DrawSplit`·`payoutLimitFor`·`finalizeYearTax`까지)
- Test: `app/test/services/pension_simulator_test.dart`

**Interfaces:**
- Consumes: `TaxCalculator.getPensionTaxRate(int age)`, `WithdrawalSource`, `WithdrawalDetail`
- Produces: `kAnnualPensionBracket`, `kRetirementEffectiveRate`, `kPenaltyRate`, `kBracketSources`, `kPayoutLimitedSources`, `class DrawSplit {int within; int over; int get total}`, `PensionSimulator.payoutLimitFor(Map<WithdrawalSource,int> pools, int year) → int`, `PensionSimulator.finalizeYearTax(Map<WithdrawalSource,DrawSplit> ledger, int age, int year) → List<WithdrawalDetail>`

- [ ] **Step 1: 실패하는 테스트 작성** — `app/test/services/pension_simulator_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pension_compass/models/simulation_result.dart';
import 'package:pension_compass/services/pension_simulator.dart';

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
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `cd app && flutter test test/services/pension_simulator_test.dart`
Expected: FAIL — `pension_simulator.dart` 미존재 (URI 에러)

- [ ] **Step 3: `app/lib/services/pension_simulator.dart` 구현 (이 Task 범위)**

```dart
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
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `cd app && flutter test test/services/pension_simulator_test.dart`
Expected: 전체 PASS

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: 시뮬레이터 코어 — 수령한도 10년룰 + 연말 세금 확정(절벽·초과·퇴직 감면)"
```

---

### Task 3: 인출 전략 4종 정의

**Files:**
- Create: `app/lib/services/withdrawal_strategies.dart`
- Test: `app/test/services/pension_simulator_test.dart` (group 추가)

**Interfaces:**
- Produces: `class DrawStep {WithdrawalSource source; bool useBracketCap; bool usePayoutCap; int activeFromAge}`, `class WithdrawalStrategy {String id; String displayName; String description; List<DrawStep> steps}`, `final List<WithdrawalStrategy> kStrategies` (순서: fill_bracket → tax_free_first → defer_taxable → pension_first — 동률 시 앞선 것 우승), `const List<WithdrawalSource> kFallbackOrder`

- [ ] **Step 1: 실패하는 테스트 추가** — 기존 테스트 파일에 group 추가

```dart
// import 추가: import 'package:pension_compass/services/withdrawal_strategies.dart';

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
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `cd app && flutter test test/services/pension_simulator_test.dart`
Expected: FAIL — withdrawal_strategies.dart 미존재

- [ ] **Step 3: `app/lib/services/withdrawal_strategies.dart` 구현**

```dart
import '../models/simulation_result.dart';

/// 인출 스텝 — 어느 풀에서, 어떤 캡을 지키며, 몇 세부터 인출할지
class DrawStep {
  final WithdrawalSource source;

  /// 1,500만원 저율 한도(절벽) 준수 — 과세재원에만 의미 있음
  final bool useBracketCap;

  /// 연금수령한도(10년 룰) 준수
  final bool usePayoutCap;

  /// 이 나이부터 인출 활성 (과세 이연 전략용)
  final int activeFromAge;

  const DrawStep(
    this.source, {
    this.useBracketCap = false,
    this.usePayoutCap = false,
    this.activeFromAge = 0,
  });
}

/// 인출 전략 — 스텝 순서 정책 (엔진은 PensionSimulator)
class WithdrawalStrategy {
  final String id;
  final String displayName;
  final String description;
  final List<DrawStep> steps;

  const WithdrawalStrategy({
    required this.id,
    required this.displayName,
    required this.description,
    required this.steps,
  });
}

const List<DrawStep> _taxFreeSteps = [
  DrawStep(WithdrawalSource.isaProfit),
  DrawStep(WithdrawalSource.isaPrincipal),
  DrawStep(WithdrawalSource.pensionNonDeducted),
];

const List<DrawStep> _taxableCappedSteps = [
  DrawStep(WithdrawalSource.pensionDeducted,
      useBracketCap: true, usePayoutCap: true),
  DrawStep(WithdrawalSource.irpSelf, useBracketCap: true, usePayoutCap: true),
  DrawStep(WithdrawalSource.earnings, useBracketCap: true, usePayoutCap: true),
];

const DrawStep _retirementCapped =
    DrawStep(WithdrawalSource.irpRetirement, usePayoutCap: true);

/// 전략 B — 매년 저율 1,500만원 한도를 채우고 부족분은 비과세로 (Fill the Bracket)
final fillBracket = WithdrawalStrategy(
  id: 'fill_bracket',
  displayName: '저율한도 채우기',
  description: '매년 과세 재원을 1,500만원 저율 한도까지 인출하고 부족분은 비과세로 충당',
  steps: [..._taxableCappedSteps, ..._taxFreeSteps, _retirementCapped],
);

/// 전략 A — 비과세 재원 우선 소진
final taxFreeFirst = WithdrawalStrategy(
  id: 'tax_free_first',
  displayName: '비과세 우선',
  description: '비과세 재원부터 소진하고 과세 재원은 저율 한도 내에서 인출',
  steps: [..._taxFreeSteps, ..._taxableCappedSteps, _retirementCapped],
);

/// 전략 C — 과세 인출을 70세(4.4%)·80세(3.3%) 저세율 구간으로 이연
final deferTaxable = WithdrawalStrategy(
  id: 'defer_taxable',
  displayName: '과세 이연 (노년 저세율)',
  description: '초기엔 비과세·퇴직금만 쓰고 과세 재원 인출을 70세 이후로 미룸',
  steps: [
    ..._taxFreeSteps,
    _retirementCapped,
    const DrawStep(WithdrawalSource.pensionDeducted,
        useBracketCap: true, usePayoutCap: true, activeFromAge: 70),
    const DrawStep(WithdrawalSource.irpSelf,
        useBracketCap: true, usePayoutCap: true, activeFromAge: 70),
    const DrawStep(WithdrawalSource.earnings,
        useBracketCap: true, usePayoutCap: true, activeFromAge: 70),
  ],
);

/// Baseline — 많은 이들이 무심코 택하는 순서 (절감액 비교 기준, 캡 미준수)
final pensionFirst = WithdrawalStrategy(
  id: 'pension_first',
  displayName: '기존 방식 (연금저축부터)',
  description: '연금저축 공제분부터 소진 — 절벽·한도를 고려하지 않는 일반적 방식',
  steps: const [
    DrawStep(WithdrawalSource.pensionDeducted),
    DrawStep(WithdrawalSource.irpSelf),
    DrawStep(WithdrawalSource.earnings),
    DrawStep(WithdrawalSource.irpRetirement),
    DrawStep(WithdrawalSource.isaProfit),
    DrawStep(WithdrawalSource.isaPrincipal),
    DrawStep(WithdrawalSource.pensionNonDeducted),
  ],
);

/// 토너먼트 참가 전략 — 순서가 동률 시 우선순위
final List<WithdrawalStrategy> kStrategies = [
  fillBracket,
  taxFreeFirst,
  deferTaxable,
  pensionFirst,
];

/// 목표 인출액 미달 시 캡 무시 폴백 순서 (세금 페널티 감수 — 현실 반영)
const List<WithdrawalSource> kFallbackOrder = [
  WithdrawalSource.isaProfit,
  WithdrawalSource.isaPrincipal,
  WithdrawalSource.pensionNonDeducted,
  WithdrawalSource.pensionDeducted,
  WithdrawalSource.irpSelf,
  WithdrawalSource.earnings,
  WithdrawalSource.irpRetirement,
];
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `cd app && flutter test test/services/pension_simulator_test.dart`
Expected: 전체 PASS

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: 인출 전략 4종 정의 (fill_bracket/tax_free_first/defer_taxable/pension_first)"
```

---

### Task 4: 시뮬레이션 엔진 `PensionSimulator.run` (TDD)

**Files:**
- Modify: `app/lib/services/pension_simulator.dart` (`run` 추가)
- Test: `app/test/services/pension_simulator_test.dart` (group 추가)

**Interfaces:**
- Consumes: Task 2의 `finalizeYearTax`/`payoutLimitFor`, Task 3의 `WithdrawalStrategy`/`kFallbackOrder`, Task 1의 `StrategyOutcome`/`PensionInput.expectedReturnRate`
- Produces: `PensionSimulator.run(PensionInput input, WithdrawalStrategy strategy) → StrategyOutcome`

- [ ] **Step 1: 실패하는 테스트 추가**

```dart
// import 추가: import 'package:pension_compass/models/pension_input.dart';

  group('PensionSimulator.run — 엔진', () {
    test('복리 성장이 earnings 풀로 편입된다 (비공제분 1억, r=5%, 2년)', () {
      const input = PensionInput(
        pensionSavings: 100000000,
        pensionSavingsDeducted: 0, // 전액 비공제 → 비과세
        irpBalance: 0,
        irpRetirementPortion: 0,
        isaMaturity: 0,
        currentAge: 58,
        targetAnnualWithdrawal: 10000000,
        simulationYears: 2,
        expectedReturnRate: 0.05,
      );
      final outcome = PensionSimulator.run(input, taxFreeFirst);
      // 1년차: 10M 인출 → 잔액 90M → 성장 4.5M
      // 2년차: 10M 인출 → 비공제 80M, earnings 4.5M → 성장 4M + 225K
      expect(outcome.totalTax, 0); // earnings 미인출 — 전부 비과세 인출
      expect(outcome.totalWithdrawn, 20000000);
      expect(outcome.finalBalance, 88725000); // 80M + 4.5M + 4.225M
    });

    test('fallback: 과세재원만으로 목표 2,400만 충족 (절벽 감수)', () {
      const input = PensionInput(
        pensionSavings: 100000000,
        pensionSavingsDeducted: 100000000, // 전액 과세재원
        irpBalance: 0,
        irpRetirementPortion: 0,
        isaMaturity: 0,
        currentAge: 58,
        targetAnnualWithdrawal: 24000000,
        simulationYears: 1,
        expectedReturnRate: 0,
      );
      final outcome = PensionSimulator.run(input, fillBracket);
      final year1 = outcome.schedule.first;
      expect(year1.totalAmount, 24000000); // 목표 충족
      // 1년차 수령한도 = 1억/10×1.2 = 1,200만 → 한도 내 1,200만은
      // 1,500만 이하라 절벽 미발동(5.5%), 한도 초과 1,200만은 16.5%
      expect(year1.totalTax, 660000 + 1980000);
    });

    test('전략 간 비교: example 입력에서 fill_bracket 세금 < pension_first 세금', () {
      final input = PensionInput.example();
      final smart = PensionSimulator.run(input, fillBracket);
      final naive = PensionSimulator.run(input, pensionFirst);
      expect(smart.totalTax, lessThan(naive.totalTax));
    });

    test('defer_taxable: 70세 전엔 과세재원 인출 없음 (재원 충분 시)', () {
      const input = PensionInput(
        pensionSavings: 200000000,
        pensionSavingsDeducted: 100000000, // 비공제 1억 + 공제 1억
        irpBalance: 0,
        irpRetirementPortion: 0,
        isaMaturity: 0,
        currentAge: 58,
        targetAnnualWithdrawal: 12000000,
        simulationYears: 5,
        expectedReturnRate: 0,
      );
      final outcome = PensionSimulator.run(input, deferTaxable);
      for (final year in outcome.schedule) {
        final taxableDrawn = year.withdrawals
            .where((d) => kBracketSources.contains(d.source))
            .fold<int>(0, (s, d) => s + d.amount);
        expect(taxableDrawn, 0, reason: '${year.age}세에 과세재원 인출됨');
      }
    });
  });
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `cd app && flutter test test/services/pension_simulator_test.dart`
Expected: FAIL — `run` 미정의

- [ ] **Step 3: `pension_simulator.dart`에 `run` 구현** — 파일 상단 import에 `import '../models/pension_input.dart';`, `import 'withdrawal_strategies.dart';` 추가 후 `PensionSimulator` 클래스에 추가:

```dart
  /// 단일 전략 시뮬레이션 — 연 단위 인출 → 연말 세금 확정 → 복리 성장 편입
  static StrategyOutcome run(PensionInput input, WithdrawalStrategy strategy) {
    final pools = <WithdrawalSource, int>{
      WithdrawalSource.isaProfit: input.isaProfit,
      WithdrawalSource.isaPrincipal: input.isaPrincipal,
      WithdrawalSource.pensionNonDeducted: input.pensionSavingsNonDeducted,
      WithdrawalSource.pensionDeducted: input.pensionSavingsDeducted,
      WithdrawalSource.irpSelf: input.irpSelfContribution,
      WithdrawalSource.earnings: 0,
      WithdrawalSource.irpRetirement: input.irpRetirementPortion,
    };

    final schedule = <YearlyWithdrawal>[];
    var totalTax = 0;
    var totalWithdrawn = 0;

    for (int year = 1; year <= input.simulationYears; year++) {
      final age = input.currentAge + year - 1;
      var payoutRemaining = payoutLimitFor(pools, year);
      var bracketRemaining = kAnnualPensionBracket;
      var remaining = input.targetAnnualWithdrawal;
      final ledger = <WithdrawalSource, DrawSplit>{};

      // 풀 차감 + 원장 기록 + 한도 소진 (amount는 호출부에서 available 이내 보장)
      void draw(WithdrawalSource src, int amount) {
        if (amount <= 0) return;
        pools[src] = (pools[src] ?? 0) - amount;
        remaining -= amount;
        final split = ledger.putIfAbsent(src, DrawSplit.new);
        if (kPayoutLimitedSources.contains(src)) {
          final within = amount.clamp(0, payoutRemaining);
          split.within += within;
          split.over += amount - within;
          payoutRemaining -= within;
          if (kBracketSources.contains(src)) {
            bracketRemaining = (bracketRemaining - within).clamp(0, 1 << 60);
          }
        } else {
          split.within += amount; // 한도 미적용 소스는 전액 within
        }
      }

      // 1) 전략 스텝 순회 (캡 준수)
      for (final step in strategy.steps) {
        if (remaining <= 0) break;
        if (age < step.activeFromAge) continue;
        final available = pools[step.source] ?? 0;
        if (available <= 0) continue;
        var cap = available;
        if (step.usePayoutCap && kPayoutLimitedSources.contains(step.source)) {
          cap = cap.clamp(0, payoutRemaining);
        }
        if (step.useBracketCap && kBracketSources.contains(step.source)) {
          cap = cap.clamp(0, bracketRemaining);
        }
        draw(step.source, remaining.clamp(0, cap));
      }

      // 2) 폴백 — 목표 미달 시 캡 무시 (세금 페널티 감수, 현실 반영)
      for (final src in kFallbackOrder) {
        if (remaining <= 0) break;
        final available = pools[src] ?? 0;
        if (available <= 0) continue;
        draw(src, remaining.clamp(0, available));
      }

      // 3) 연말 세금 확정
      final yearly = YearlyWithdrawal(
        year: year,
        age: age,
        withdrawals: finalizeYearTax(ledger, age, year),
      );
      schedule.add(yearly);
      totalTax += yearly.totalTax;
      totalWithdrawn += yearly.totalAmount;

      // 4) 복리 성장 — 남은 잔액 × 수익률, 전액 과세재원(운용수익) 편입
      var growth = 0;
      pools.forEach((src, balance) {
        if (balance > 0) growth += (balance * input.expectedReturnRate).round();
      });
      pools[WithdrawalSource.earnings] =
          (pools[WithdrawalSource.earnings] ?? 0) + growth;

      if (pools.values.every((v) => v <= 0)) break;
    }

    // 기말 잔액과 잠재세 (근사: 과세재원×기말나이 저율, 퇴직금×3.5%)
    final endAge = input.currentAge + schedule.length - 1;
    final taxableLeft = kBracketSources.fold<int>(
        0, (s, src) => s + (pools[src] ?? 0));
    final retirementLeft = pools[WithdrawalSource.irpRetirement] ?? 0;
    final latentTax =
        (taxableLeft * TaxCalculator.getPensionTaxRate(endAge)).round() +
            (retirementLeft * kRetirementEffectiveRate * 0.7).round();
    final finalBalance = pools.values.fold<int>(0, (s, v) => s + v);

    return StrategyOutcome(
      strategyId: strategy.id,
      strategyName: strategy.displayName,
      schedule: schedule,
      totalTax: totalTax,
      totalWithdrawn: totalWithdrawn,
      finalBalance: finalBalance,
      latentTax: latentTax,
    );
  }
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `cd app && flutter test test/services/pension_simulator_test.dart`
Expected: 전체 PASS

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: 시뮬레이션 엔진 — 캡 준수 인출 + 폴백 + 복리 earnings 편입"
```

---

### Task 5: 토너먼트 오케스트레이션 — `WithdrawalOptimizer.optimize` 재작성 (TDD)

**Files:**
- Rewrite: `app/lib/services/withdrawal_optimizer.dart` (전체 교체)
- Test: `app/test/services/withdrawal_optimizer_test.dart`

**Interfaces:**
- Consumes: `PensionSimulator.run`, `kStrategies`
- Produces: `WithdrawalOptimizer.optimize(PensionInput) → SimulationResult` (기존 시그니처 유지 — provider 무수정)

- [ ] **Step 1: 실패하는 테스트 작성** — `app/test/services/withdrawal_optimizer_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pension_compass/models/pension_input.dart';
import 'package:pension_compass/services/withdrawal_optimizer.dart';

void main() {
  group('WithdrawalOptimizer.optimize — 전략 토너먼트', () {
    final result = WithdrawalOptimizer.optimize(PensionInput.example());

    test('4개 전략 결과가 전부 담긴다', () {
      expect(result.outcomes.length, 4);
    });

    test('절감액 ≥ 0 (우승 전략 세금 ≤ baseline 세금)', () {
      expect(result.totalTaxBaseline, greaterThanOrEqualTo(result.totalTaxOptimal));
      expect(result.savings, greaterThanOrEqualTo(0));
    });

    test('우승 전략은 taxBurden 최소', () {
      final winner = result.outcomes
          .firstWhere((o) => o.strategyId == result.optimalStrategyId);
      for (final o in result.outcomes) {
        expect(winner.taxBurden, lessThanOrEqualTo(o.taxBurden));
      }
    });

    test('기존 API 계약: schedule·optimalSequence·baselineSchedule 채워짐', () {
      expect(result.schedule, isNotEmpty);
      expect(result.optimalSequence, isNotEmpty);
      expect(result.baselineSchedule, isNotEmpty);
      expect(result.optimalStrategyName, isNotEmpty);
      expect(result.cumulativeTaxBaseline.length, result.baselineSchedule.length);
    });

    test('optimalSequence는 실제 인출 발생 순서 (중복 없음)', () {
      expect(result.optimalSequence.toSet().length, result.optimalSequence.length);
    });
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `cd app && flutter test test/services/withdrawal_optimizer_test.dart`
Expected: FAIL — `outcomes` 미구현 (구 로직)

- [ ] **Step 3: `withdrawal_optimizer.dart` 전체 교체**

```dart
import '../models/pension_input.dart';
import '../models/simulation_result.dart';
import 'pension_simulator.dart';
import 'withdrawal_strategies.dart';

/// 인출 전략 토너먼트 — 4개 후보 전략을 전부 시뮬레이션해 최적을 고른다
class WithdrawalOptimizer {
  WithdrawalOptimizer._();

  static SimulationResult optimize(PensionInput input) {
    final outcomes =
        kStrategies.map((s) => PensionSimulator.run(input, s)).toList();

    // 우승: taxBurden(낸 세금+잠재세) 최소 — 동률 시 kStrategies 순서 우선
    var best = outcomes.first;
    for (final o in outcomes.skip(1)) {
      if (o.taxBurden < best.taxBurden) best = o;
    }
    final baseline =
        outcomes.firstWhere((o) => o.strategyId == 'pension_first');

    // 최적 시퀀스 = 우승 스케줄에서 실제 인출이 발생한 소스의 등장 순서
    final sequence = <WithdrawalSource>[];
    for (final year in best.schedule) {
      for (final d in year.withdrawals) {
        if (!sequence.contains(d.source)) sequence.add(d.source);
      }
    }

    return SimulationResult(
      schedule: best.schedule,
      totalTaxOptimal: best.totalTax,
      totalTaxBaseline: baseline.totalTax,
      optimalSequence: sequence,
      outcomes: outcomes,
      optimalStrategyId: best.strategyId,
      optimalStrategyName: best.strategyName,
      baselineSchedule: baseline.schedule,
    );
  }
}
```

- [ ] **Step 4: 전체 테스트 통과 확인**

Run: `cd app && flutter test`
Expected: 전체 PASS (widget_test.dart 실패 시 해당 테스트가 구 로직 의존인지 확인 — Task 7에서 정리, 신규 로직 기인이면 즉시 수정)

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: 전략 토너먼트 — 4전략 시뮬레이션 후 taxBurden 최소 전략 선택"
```

---

### Task 6: UI·저장소 배선 (수익률 입력 + 결과 화면 정합)

**Files:**
- Modify: `app/lib/providers/pension_provider.dart`
- Modify: `app/lib/services/local_storage_service.dart`
- Modify: `app/lib/screens/home_screen.dart`
- Modify: `app/lib/screens/result_screen.dart`

**Interfaces:**
- Consumes: Task 1 모델, Task 5의 `SimulationResult.optimalStrategyName`/`cumulativeTaxBaseline`
- Produces: `PensionInputNotifier.updateExpectedReturnRate(double)`

- [ ] **Step 1: provider에 수익률 업데이트 추가** — `updateSimulationYears` 아래에:

```dart
  void updateExpectedReturnRate(double value) {
    state = state.copyWith(expectedReturnRate: value.clamp(0.0, 0.20));
  }
```

- [ ] **Step 2: storage에 수익률 저장/로드 추가** — 키 상수에 `static const String _keyExpectedReturnRate = 'expected_return_rate';`, `saveInput`에 `await _prefs.setDouble(_keyExpectedReturnRate, input.expectedReturnRate);`, `loadInput` 반환 객체에 `expectedReturnRate: _prefs.getDouble(_keyExpectedReturnRate) ?? 0.04,` 추가.

- [ ] **Step 3: home_screen '기본 정보' 카드에 수익률 스텝퍼 추가** — '연간 목표 인출액' `AmountInputField` 바로 아래에:

```dart
                const SizedBox(height: 16),
                NumberInputField(
                  label: '예상 연 수익률 (복리)',
                  value: (input.expectedReturnRate * 100).round(),
                  suffix: '%',
                  min: 0,
                  max: 15,
                  onChanged: (v) => ref
                      .read(pensionInputProvider.notifier)
                      .updateExpectedReturnRate(v / 100.0),
                ),
```

- [ ] **Step 4: result_screen 정합 3건**

(a) 절감 효과 카드의 '최적 방식' `_buildTaxCard` — `subtitle: '비과세부터 인출'` → `subtitle: result.optimalStrategyName` (하드코딩 제거, 우승 전략명 표시).

(b) `_buildChart`의 가짜 baseline(평균 분배) 제거 — 기존:

```dart
    // 기존 방식 누적 세금 계산 (간이)
    final cumulativeBaseline = <int>[];
    int cumulative = 0;
    for (int i = 0; i < result.schedule.length; i++) {
      // 기존 방식은 연 평균 세금이 더 높다고 가정
      cumulative += (result.totalTaxBaseline / result.schedule.length).round();
      cumulativeBaseline.add(cumulative);
    }
```

교체:

```dart
    // 기존 방식 누적 세금 — baseline 전략의 실제 연도별 스케줄
    final cumulativeBaseline = result.cumulativeTaxBaseline;
```

(단, 두 스케줄 길이가 다를 수 있으므로 `maxY` 계산과 spots 생성은 각자 리스트 길이 기준 유지 — 기존 코드가 이미 각자 length로 순회하므로 추가 수정 불요. `cumulativeBaseline`이 비어있을 때 `maxY` fallback도 기존 코드 그대로 동작.)

(c) `_buildExpertTips`의 기존 16.5% 팁카드 아래에 수익률·수령한도 가정 팁 1개 추가:

```dart
          const SizedBox(height: 12),

          // 4. 시뮬레이션 가정 안내
          _buildTipCard(
            icon: Icons.trending_up,
            iconColor: AppColors.navy,
            title: '시뮬레이션 가정',
            content: '남은 잔액은 입력한 연 수익률로 복리 성장하며, 운용수익은 세법에 따라 과세 재원으로 편입해 계산합니다. 연금수령한도(10년 룰) 초과 인출은 16.5% 과세로 반영됩니다. 4가지 인출 전략을 전 기간 시뮬레이션해 비교한 결과입니다.',
            backgroundColor: AppColors.navy.withAlpha(15),
          ),
```

- [ ] **Step 5: 컴파일·전체 테스트·수동 확인**

Run: `cd app && flutter analyze && flutter test`
Expected: analyze 에러 0, 테스트 전체 PASS

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "feat: 수익률 입력 UI + 결과화면 우승전략명·실제 baseline 차트·가정 안내"
```

---

### Task 7: 문서 갱신 + 최종 검증

**Files:**
- Modify: `docs/ALGORITHM.md`
- 확인: `app/test/widget_test.dart`

- [ ] **Step 1: widget_test.dart 확인·정리**

Read 후: Flutter 기본 counter 테스트(보일러플레이트)라면 앱 타이틀 스모크 테스트로 교체, 실제 테스트라면 신규 로직에 맞게 수정. 교체용 코드:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pension_compass/main.dart';

void main() {
  testWidgets('앱이 크래시 없이 기동한다', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: PensionCompassApp()));
    expect(find.text('연금나침반'), findsOneWidget);
  });
}
```

(main.dart의 루트 위젯 클래스명 확인 후 `PensionCompassApp` 부분을 실제 이름으로 사용)

- [ ] **Step 2: `docs/ALGORITHM.md`에 v2 섹션 추가** — 문서 상단에 아래 섹션 삽입:

```markdown
## v2 (2026-07-09) — 다이내믹 시뮬레이션 엔진

v1의 정적 Greedy를 폐기하고 **전략 토너먼트** 구조로 재설계.

### 세법 반영 (v1 대비 변경)
1. **1,500만원 절벽**: 과세재원 연간 인정액 합계 > 1,500만원 → 그 해 인정액 **전액** 16.5%
   (v1은 초과분만 16.5%로 계산 — 세금 과소 산정 버그였음). 종합과세 선택은 미반영(보수 가정, UI 고지).
2. **연금수령한도 (10년 룰)**: 연차 1~10년 한도 = 연초 연금계좌 평가액(ISA 제외) ÷ (11−연차) × 1.2.
   초과 인출: 과세재원 16.5% 기타소득세, 퇴직금분 감면 소멸.
3. **복리 성장**: 연말 잔액 × 예상수익률(기본 4%)을 운용수익(earnings) 풀로 편입 — 운용수익은 과세재원.
4. **퇴직소득세**: 실효세율 5% 가정 × 감면(1~10년차 70%, 11년차+ 60%, 한도 초과 100%).

### 전략 토너먼트
| id | 전략 | 요지 |
|---|---|---|
| fill_bracket | 저율한도 채우기 | 매년 과세재원 1,500만 저율 한도 소진 → 부족분 비과세 |
| tax_free_first | 비과세 우선 | 비과세 소진 → 과세재원 한도 내 |
| defer_taxable | 과세 이연 | 과세 인출을 70세(4.4%)·80세(3.3%) 구간으로 미룸 |
| pension_first | 기존 방식 | 공제분부터 (절감액 비교 기준, baseline) |

우승 판정: `taxBurden = 낸 세금 + 기말잔액 잠재세` 최소. 세금은 연말 원장(ledger) 일괄 확정
(절벽·한도 판정이 연간 합산 기준이므로).

### MVP 명시 가정
- 수령연차 = 시뮬레이션 연차 (2013.3.1 이전 가입 특례 미반영)
- ISA는 연금계좌 평가액에서 제외 (보수적)
- 계좌 내 법정 인출 순서는 계좌 분리 운영을 전제로 풀 단위 자유 배분 가정 (UI 팁으로 고지)
```

- [ ] **Step 3: 최종 검증**

Run: `cd app && flutter analyze && flutter test`
Expected: analyze 에러 0, 전체 테스트 PASS — 출력 확인 후에만 완료 주장

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "docs: ALGORITHM.md v2 — 절벽·수령한도·복리·전략 토너먼트 명세"
```

---

## Self-Review 결과

- **Spec coverage:** 복리(Task 1·4), 절벽 전액 과세(Task 2), 수령한도 10년 룰(Task 2·4), 퇴직세 연차 감면(Task 2), 6-pool 유지+earnings(Task 1), int 원 단위(전체), 전략 4종 토너먼트(Task 3·5), baseline 비교 유지(Task 5), Gemini 세금 덮어쓰기 버그 회피(Task 2 — 소스·구분별 detail 분리로 구조적 원천 차단), UI 면책·가정 고지(Task 6), 실제 baseline 차트(Task 6) — 전부 매핑됨.
- **알려진 한계(의도적 제외):** 종합과세 선택 계산(문구 방어), ISA 미이전 시나리오 세분화, 퇴직소득세 정밀 계산(실효세율 입력은 P2), 전략 비교 표 UI(P1 — 데이터는 `outcomes`로 이미 노출).
