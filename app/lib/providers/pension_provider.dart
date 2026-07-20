import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/pension_input.dart';
import '../models/saved_scenario.dart';
import '../models/simulation_result.dart';
import '../services/monte_carlo_simulator.dart';
import '../services/withdrawal_optimizer.dart';
import '../services/local_storage_service.dart';

/// LocalStorageService Provider
final localStorageProvider = FutureProvider<LocalStorageService>((ref) async {
  return LocalStorageService.create();
});

/// 연금 입력 상태 Provider
final pensionInputProvider = StateNotifierProvider<PensionInputNotifier, PensionInput>(
  (ref) => PensionInputNotifier(),
);

class PensionInputNotifier extends StateNotifier<PensionInput> {
  PensionInputNotifier() : super(PensionInput.empty());

  void updatePensionSavings(int value) {
    state = state.copyWith(
      pensionSavings: value,
      // 공제분이 잔액보다 크면 잔액으로 조정
      pensionSavingsDeducted: state.pensionSavingsDeducted > value 
          ? value 
          : state.pensionSavingsDeducted,
    );
  }

  void updatePensionSavingsDeducted(int value) {
    state = state.copyWith(
      pensionSavingsDeducted: value.clamp(0, state.pensionSavings),
    );
  }

  void updateIrpBalance(int value) {
    state = state.copyWith(
      irpBalance: value,
      irpRetirementPortion: state.irpRetirementPortion > value 
          ? value 
          : state.irpRetirementPortion,
    );
  }

  void updateIrpRetirementPortion(int value) {
    state = state.copyWith(
      irpRetirementPortion: value.clamp(0, state.irpBalance),
    );
  }

  void updateIsaMaturity(int value) {
    state = state.copyWith(
      isaMaturity: value,
      isaProfit: state.isaProfit > value ? value : state.isaProfit,
    );
  }

  void updateIsaProfit(int value) {
    state = state.copyWith(
      isaProfit: value.clamp(0, state.isaMaturity),
    );
  }

  void updateCurrentAge(int value) {
    state = state.copyWith(currentAge: value.clamp(20, 100));
  }

  void updateTargetAnnualWithdrawal(int value) {
    state = state.copyWith(targetAnnualWithdrawal: value.clamp(0, 1000000000));
  }

  void updateSimulationYears(int value) {
    state = state.copyWith(simulationYears: value.clamp(1, 50));
  }

  void updateExpectedReturnRate(double value) {
    state = state.copyWith(expectedReturnRate: value.clamp(0.0, 0.20));
  }

  void updateIncomeLevel(IncomeLevel level) {
    state = state.copyWith(incomeLevel: level);
  }

  /// 국민연금 월수령액 입력 (5번째 카드 필드 또는 auto-fill)
  /// 개시연령이 아직 비어있으면 화면 표시 기본값(65세, home_screen.dart
  /// `input.npsStartAge ?? 65`)과 state를 동기화한다 — 그렇지 않으면 사용자가
  /// 월수령액만 입력하고 화면의 "65"를 그대로 둘 때 npsStartAge가 null로 남아
  /// hasNps=false 로 국민연금이 조용히 미반영된다.
  /// 반대 방향(개시연령만 먼저 입력)은 대칭 처리하지 않는다 — 월수령액은
  /// 기본값을 지어낼 수 없으므로 기존 부분입력 경고(스낵바)가 정당하다.
  void updateNpsMonthlyAmount(int value) {
    state = state.copyWith(
      npsMonthlyAmount: value,
      npsStartAge: state.npsStartAge ?? 65,
    );
  }

  /// 국민연금 수급 개시연령 입력 (5번째 카드 필드 또는 auto-fill)
  void updateNpsStartAge(int value) {
    state = state.copyWith(npsStartAge: value);
  }

  /// 국민연금 월수령액·개시연령 동시 설정 (미니 계산기 auto-fill 전용)
  void setNps(int monthlyAmount, int startAge) {
    state = state.copyWith(npsMonthlyAmount: monthlyAmount, npsStartAge: startAge);
  }

  /// 국민연금 정보 초기화 (5번째 카드 접힘 시)
  /// ⚠️ copyWith는 `?? this.x` 패턴이라 null로 되돌릴 수 없다 — 새 PensionInput을
  /// 직접 생성해 npsMonthlyAmount/npsStartAge만 null로 리셋한다.
  void clearNps() {
    state = PensionInput(
      pensionSavings: state.pensionSavings,
      pensionSavingsDeducted: state.pensionSavingsDeducted,
      irpBalance: state.irpBalance,
      irpRetirementPortion: state.irpRetirementPortion,
      isaMaturity: state.isaMaturity,
      isaProfit: state.isaProfit,
      currentAge: state.currentAge,
      targetAnnualWithdrawal: state.targetAnnualWithdrawal,
      simulationYears: state.simulationYears,
      incomeLevel: state.incomeLevel,
      expectedReturnRate: state.expectedReturnRate,
      npsMonthlyAmount: null,
      npsStartAge: null,
    );
  }

  void reset() {
    state = PensionInput.empty();
  }

  /// 예시 입력 — 자산·기본 정보만 예시값으로 교체하고 **국민연금 입력은 보존**한다.
  ///
  /// E2E 실측 버그(갤럭시 S25): auto-fill 후 "예시 입력"을 탭하면
  /// `PensionInput.example()` 통째 교체로 nps 필드가 null 리셋되는데,
  /// 5번째 카드의 TextField 컨트롤러는 기존 텍스트("66")를, 개시연령 스텝퍼는
  /// `?? 65` 기본값을 계속 표시해 — 화면은 입력된 것처럼 보이는데 state는 비어
  /// 있는 상태/표시 불일치가 발생, 사용자가 국민연금이 반영됐다고 착각한 채
  /// 잘못된 시뮬레이션 결과를 봤다. 예시 입력은 자산 예시일 뿐 국민연금 입력과
  /// 무관하므로 현재 nps 값을 그대로 이어붙인다 (copyWith는 null 인자가
  /// no-op이라 미입력(null) 상태도 자연스럽게 유지된다).
  void loadExample() {
    final cur = state;
    state = PensionInput.example().copyWith(
      npsMonthlyAmount: cur.npsMonthlyAmount,
      npsStartAge: cur.npsStartAge,
    );
  }

  /// 저장된 입력값 불러오기
  void loadFromStorage(PensionInput? savedInput) {
    if (savedInput != null) {
      state = savedInput;
    }
  }

  /// 현재 입력값 반환 (저장용)
  PensionInput get currentInput => state;
}

/// 시뮬레이션 결과 Provider
final simulationResultProvider = Provider<SimulationResult?>((ref) {
  final input = ref.watch(pensionInputProvider);
  
  // 유효하지 않은 입력이면 null 반환
  if (!input.isValid || input.totalAssets == 0) {
    return null;
  }
  
  return WithdrawalOptimizer.optimize(input);
});

/// 시뮬레이션 실행 가능 여부
final canSimulateProvider = Provider<bool>((ref) {
  final input = ref.watch(pensionInputProvider);
  return input.isValid && input.totalAssets > 0;
});

/// 총 자산 Provider
final totalAssetsProvider = Provider<int>((ref) {
  final input = ref.watch(pensionInputProvider);
  return input.totalAssets;
});

/// 몬테카를로 성공률 Provider (v1.3)
///
/// 1,000경로 실측 5ms(JIT 기준, AOT 는 더 빠름)라 isolate 없이 동기 계산한다.
/// 입력이 같으면 시드가 같아 항상 같은 결과 — 재계산마다 확률이 흔들리지
/// 않는다 (신뢰 보호). 결과가 null 이면 시뮬레이션 불가 상태.
final monteCarloProvider = Provider<MonteCarloSummary?>((ref) {
  final input = ref.watch(pensionInputProvider);
  final result = ref.watch(simulationResultProvider);
  if (result == null) return null;
  return MonteCarloSimulator.simulate(input, result.optimalStrategyId);
});

/// 저장된 시나리오 목록 Provider (v1.2 — 시나리오 저장·비교)
final savedScenariosProvider =
    StateNotifierProvider<SavedScenariosNotifier, List<SavedScenario>>(
  (ref) => SavedScenariosNotifier(),
);

class SavedScenariosNotifier extends StateNotifier<List<SavedScenario>> {
  /// storage 주입은 테스트 전용 — 실사용은 lazy 생성 (SharedPreferences 캐시됨)
  SavedScenariosNotifier([this._storage]) : super(const []);

  LocalStorageService? _storage;

  Future<LocalStorageService> _s() async =>
      _storage ??= await LocalStorageService.create();

  Future<void> load() async {
    state = (await _s()).loadScenarios();
  }

  /// 저장 성공 여부 반환 (false = 최대 개수 초과)
  Future<bool> save(String name, PensionInput input) async {
    final s = await _s();
    final ok = await s.saveScenario(SavedScenario(
      name: name,
      savedAt: DateTime.now().toIso8601String(),
      input: input,
    ));
    if (ok) state = s.loadScenarios();
    return ok;
  }

  Future<void> remove(String name) async {
    final s = await _s();
    await s.deleteScenario(name);
    state = s.loadScenarios();
  }
}
