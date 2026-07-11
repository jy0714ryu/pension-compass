import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/pension_input.dart';
import '../models/simulation_result.dart';
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

  void loadExample() {
    state = PensionInput.example();
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
