/// 연금 자산 입력 데이터 모델
class PensionInput {
  /// 연금저축 잔액 (원)
  final int pensionSavings;
  
  /// 연금저축 중 세액공제 받은 금액 (원)
  final int pensionSavingsDeducted;
  
  /// IRP 잔액 (원)
  final int irpBalance;
  
  /// IRP 중 퇴직금 이전분 (원)
  final int irpRetirementPortion;
  
  /// ISA 만기 예정액 (원)
  final int isaMaturity;
  
  /// ISA 수익분 (원) - 비과세 적용
  final int isaProfit;
  
  /// 현재 나이
  final int currentAge;
  
  /// 연간 목표 인출액 (원)
  final int targetAnnualWithdrawal;
  
  /// 시뮬레이션 기간 (년)
  final int simulationYears;
  
  /// 소득 수준 (세액공제율 결정용)
  final IncomeLevel incomeLevel;

  /// 예상 연평균 운용 수익률 (복리, 예: 0.04 = 4%)
  final double expectedReturnRate;

  const PensionInput({
    required this.pensionSavings,
    required this.pensionSavingsDeducted,
    required this.irpBalance,
    required this.irpRetirementPortion,
    required this.isaMaturity,
    this.isaProfit = 0,
    required this.currentAge,
    required this.targetAnnualWithdrawal,
    this.simulationYears = 20,
    this.incomeLevel = IncomeLevel.high,
    this.expectedReturnRate = 0.04,
  });

  /// 연금저축 중 세액공제 안 받은 금액
  int get pensionSavingsNonDeducted => pensionSavings - pensionSavingsDeducted;

  /// IRP 중 자기 납입분
  int get irpSelfContribution => irpBalance - irpRetirementPortion;

  /// ISA 원금
  int get isaPrincipal => isaMaturity - isaProfit;

  /// 총 자산
  int get totalAssets => pensionSavings + irpBalance + isaMaturity;

  /// 유효성 검사
  bool get isValid {
    return pensionSavings >= 0 &&
        pensionSavingsDeducted >= 0 &&
        pensionSavingsDeducted <= pensionSavings &&
        irpBalance >= 0 &&
        irpRetirementPortion >= 0 &&
        irpRetirementPortion <= irpBalance &&
        isaMaturity >= 0 &&
        isaProfit >= 0 &&
        isaProfit <= isaMaturity &&
        currentAge >= 20 &&
        currentAge <= 100 &&
        targetAnnualWithdrawal > 0 &&
        expectedReturnRate >= 0 &&
        expectedReturnRate <= 0.20;
  }

  PensionInput copyWith({
    int? pensionSavings,
    int? pensionSavingsDeducted,
    int? irpBalance,
    int? irpRetirementPortion,
    int? isaMaturity,
    int? isaProfit,
    int? currentAge,
    int? targetAnnualWithdrawal,
    int? simulationYears,
    IncomeLevel? incomeLevel,
    double? expectedReturnRate,
  }) {
    return PensionInput(
      pensionSavings: pensionSavings ?? this.pensionSavings,
      pensionSavingsDeducted: pensionSavingsDeducted ?? this.pensionSavingsDeducted,
      irpBalance: irpBalance ?? this.irpBalance,
      irpRetirementPortion: irpRetirementPortion ?? this.irpRetirementPortion,
      isaMaturity: isaMaturity ?? this.isaMaturity,
      isaProfit: isaProfit ?? this.isaProfit,
      currentAge: currentAge ?? this.currentAge,
      targetAnnualWithdrawal: targetAnnualWithdrawal ?? this.targetAnnualWithdrawal,
      simulationYears: simulationYears ?? this.simulationYears,
      incomeLevel: incomeLevel ?? this.incomeLevel,
      expectedReturnRate: expectedReturnRate ?? this.expectedReturnRate,
    );
  }

  /// 기본값 (테스트/예시용)
  factory PensionInput.example() {
    return const PensionInput(
      pensionSavings: 100000000,  // 1억
      pensionSavingsDeducted: 80000000,  // 8천만원 공제받음
      irpBalance: 50000000,  // 5천만원
      irpRetirementPortion: 40000000,  // 4천만원 퇴직금
      isaMaturity: 30000000,  // 3천만원
      isaProfit: 5000000,  // 500만원 수익
      currentAge: 58,
      targetAnnualWithdrawal: 24000000,  // 연 2400만원
      simulationYears: 20,
      expectedReturnRate: 0.04,
    );
  }

  /// 빈 입력 (초기값)
  factory PensionInput.empty() {
    return const PensionInput(
      pensionSavings: 0,
      pensionSavingsDeducted: 0,
      irpBalance: 0,
      irpRetirementPortion: 0,
      isaMaturity: 0,
      isaProfit: 0,
      currentAge: 55,
      targetAnnualWithdrawal: 24000000,
      simulationYears: 20,
      expectedReturnRate: 0.04,
    );
  }
}

/// 소득 수준 (세액공제율 결정)
enum IncomeLevel {
  /// 총급여 5,500만원 이하 (16.5% 공제율)
  low,
  /// 총급여 5,500만원 초과 (13.2% 공제율)
  high,
}
