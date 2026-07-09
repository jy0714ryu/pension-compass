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
