import '../models/pension_input.dart';
import '../models/simulation_result.dart';
import 'tax_calculator.dart';

/// 연금소득 분리과세 연간 한도 (원)
const int _annualPensionLimit = 15000000; // 1,500만원

/// 인출 순서 최적화 서비스
class WithdrawalOptimizer {
  WithdrawalOptimizer._();

  /// 최적화 시뮬레이션 실행
  static SimulationResult optimize(PensionInput input) {
    // 자금 풀 초기화
    final pools = _initializePools(input);
    
    // 최적화 스케줄 계산
    final optimalSchedule = _calculateOptimalSchedule(
      pools: pools,
      input: input,
    );
    
    // 기존 방식 (비최적) 스케줄 계산
    final baselineSchedule = _calculateBaselineSchedule(input);
    
    // 최적 인출 순서 추출
    final optimalSequence = _extractOptimalSequence(pools, input);
    
    // 총 세금 계산
    final totalTaxOptimal = optimalSchedule.fold<int>(
      0, (sum, year) => sum + year.totalTax,
    );
    final totalTaxBaseline = baselineSchedule.fold<int>(
      0, (sum, year) => sum + year.totalTax,
    );
    
    return SimulationResult(
      schedule: optimalSchedule,
      totalTaxOptimal: totalTaxOptimal,
      totalTaxBaseline: totalTaxBaseline,
      optimalSequence: optimalSequence,
    );
  }

  /// 자금 풀 초기화
  static Map<WithdrawalSource, int> _initializePools(PensionInput input) {
    return {
      WithdrawalSource.isaProfit: input.isaProfit,
      WithdrawalSource.isaPrincipal: input.isaPrincipal,
      WithdrawalSource.pensionNonDeducted: input.pensionSavingsNonDeducted,
      WithdrawalSource.pensionDeducted: input.pensionSavingsDeducted,
      WithdrawalSource.irpSelf: input.irpSelfContribution,
      WithdrawalSource.irpRetirement: input.irpRetirementPortion,
    };
  }

  /// 최적화 스케줄 계산 (Greedy 알고리즘 + 1,500만원 분리과세 한도 적용)
  /// 
  /// 핵심 최적화 로직:
  /// 1. 비과세 계좌(ISA, 연금저축 비공제분)를 먼저 소진
  /// 2. 연금저축/IRP 공제분은 연 1,500만원까지만 분리과세(3.3~5.5%)
  /// 3. 1,500만원 초과 시 16.5% 기타소득세 적용 → 비과세 계좌 우선 인출로 회피
  static List<YearlyWithdrawal> _calculateOptimalSchedule({
    required Map<WithdrawalSource, int> pools,
    required PensionInput input,
  }) {
    final schedule = <YearlyWithdrawal>[];
    final currentPools = Map<WithdrawalSource, int>.from(pools);
    
    for (int year = 1; year <= input.simulationYears; year++) {
      final age = input.currentAge + year - 1;
      final target = input.targetAnnualWithdrawal;
      var remaining = target;
      final withdrawals = <WithdrawalDetail>[];
      
      // 해당 연도 분리과세 한도 추적
      var pensionWithdrawalThisYear = 0;
      
      // 1단계: 비과세 계좌 먼저 (ISA, 연금저축 비공제분)
      final taxFreeOrder = [
        WithdrawalSource.isaProfit,
        WithdrawalSource.isaPrincipal,
        WithdrawalSource.pensionNonDeducted,
      ];
      
      for (final source in taxFreeOrder) {
        if (remaining <= 0) break;
        
        final available = currentPools[source] ?? 0;
        if (available <= 0) continue;
        
        final withdrawal = remaining.clamp(0, available);
        if (withdrawal <= 0) continue;
        
        withdrawals.add(WithdrawalDetail(
          source: source,
          amount: withdrawal,
          tax: 0, // 비과세
          taxRate: 0,
        ));
        
        currentPools[source] = available - withdrawal;
        remaining -= withdrawal;
      }
      
      // 2단계: 분리과세 대상 (연금저축 공제분, IRP) - 1,500만원 한도 적용
      final taxableOrder = [
        WithdrawalSource.pensionDeducted,
        WithdrawalSource.irpSelf,
        WithdrawalSource.irpRetirement,
      ];
      
      for (final source in taxableOrder) {
        if (remaining <= 0) break;
        
        final available = currentPools[source] ?? 0;
        if (available <= 0) continue;
        
        // IRP 퇴직금분은 분리과세 한도와 별개 (퇴직소득세 적용)
        final isRetirementPortion = source == WithdrawalSource.irpRetirement;
        
        int withdrawal;
        double taxRate;
        int tax;
        
        if (isRetirementPortion) {
          // 퇴직금분: 퇴직소득세 70% (30% 감면) 적용
          withdrawal = remaining.clamp(0, available);
          taxRate = 0.035; // 평균 퇴직소득세 × 70%
          tax = (withdrawal * taxRate).round();
        } else {
          // 연금저축/IRP 공제분: 1,500만원 한도 체크
          final remainingLimit = _annualPensionLimit - pensionWithdrawalThisYear;
          
          if (remainingLimit <= 0) {
            // 한도 초과: 16.5% 기타소득세 적용
            withdrawal = remaining.clamp(0, available);
            taxRate = 0.165;
            tax = (withdrawal * taxRate).round();
          } else {
            // 한도 내: 분리과세 적용
            final withinLimit = remaining.clamp(0, remainingLimit).clamp(0, available);
            final overLimit = (remaining - withinLimit).clamp(0, available - withinLimit);
            
            // 한도 내 금액
            if (withinLimit > 0) {
              taxRate = TaxCalculator.getPensionTaxRate(age);
              tax = (withinLimit * taxRate).round();
              
              withdrawals.add(WithdrawalDetail(
                source: source,
                amount: withinLimit,
                tax: tax,
                taxRate: taxRate * 100,
              ));
              
              currentPools[source] = available - withinLimit;
              remaining -= withinLimit;
              pensionWithdrawalThisYear += withinLimit;
            }
            
            // 한도 초과분 (16.5% 적용)
            if (overLimit > 0 && remaining > 0) {
              final actualOverLimit = remaining.clamp(0, currentPools[source] ?? 0);
              if (actualOverLimit > 0) {
                withdrawals.add(WithdrawalDetail(
                  source: source,
                  amount: actualOverLimit,
                  tax: (actualOverLimit * 0.165).round(),
                  taxRate: 16.5,
                ));
                
                currentPools[source] = (currentPools[source] ?? 0) - actualOverLimit;
                remaining -= actualOverLimit;
              }
            }
            
            continue; // 이미 처리됨
          }
        }
        
        if (withdrawal <= 0) continue;
        
        withdrawals.add(WithdrawalDetail(
          source: source,
          amount: withdrawal,
          tax: tax,
          taxRate: taxRate * 100,
        ));
        
        currentPools[source] = available - withdrawal;
        remaining -= withdrawal;
        
        if (!isRetirementPortion) {
          pensionWithdrawalThisYear += withdrawal;
        }
      }
      
      schedule.add(YearlyWithdrawal(
        year: year,
        age: age,
        withdrawals: withdrawals,
      ));
      
      // 모든 자금 소진 시 종료
      if (currentPools.values.every((v) => v <= 0)) {
        break;
      }
    }
    
    return schedule;
  }

  /// 기존 방식 스케줄 (연금저축 먼저 - 비최적)
  static List<YearlyWithdrawal> _calculateBaselineSchedule(PensionInput input) {
    final schedule = <YearlyWithdrawal>[];
    
    // 비최적 순서: 연금저축 공제분 → IRP → ISA → 비공제분
    final pools = {
      WithdrawalSource.pensionDeducted: input.pensionSavingsDeducted,
      WithdrawalSource.irpSelf: input.irpSelfContribution,
      WithdrawalSource.irpRetirement: input.irpRetirementPortion,
      WithdrawalSource.isaProfit: input.isaProfit,
      WithdrawalSource.isaPrincipal: input.isaPrincipal,
      WithdrawalSource.pensionNonDeducted: input.pensionSavingsNonDeducted,
    };
    
    final sourceOrder = [
      WithdrawalSource.pensionDeducted,
      WithdrawalSource.irpSelf,
      WithdrawalSource.irpRetirement,
      WithdrawalSource.isaProfit,
      WithdrawalSource.isaPrincipal,
      WithdrawalSource.pensionNonDeducted,
    ];
    
    for (int year = 1; year <= input.simulationYears; year++) {
      final age = input.currentAge + year - 1;
      final target = input.targetAnnualWithdrawal;
      var remaining = target;
      final withdrawals = <WithdrawalDetail>[];
      
      for (final source in sourceOrder) {
        if (remaining <= 0) break;
        
        final available = pools[source] ?? 0;
        if (available <= 0) continue;
        
        final withdrawal = remaining.clamp(0, available);
        if (withdrawal <= 0) continue;
        
        final taxRate = _getTaxRate(source, age);
        final tax = (withdrawal * taxRate).round();
        
        withdrawals.add(WithdrawalDetail(
          source: source,
          amount: withdrawal,
          tax: tax,
          taxRate: taxRate * 100,
        ));
        
        pools[source] = available - withdrawal;
        remaining -= withdrawal;
      }
      
      schedule.add(YearlyWithdrawal(
        year: year,
        age: age,
        withdrawals: withdrawals,
      ));
      
      if (pools.values.every((v) => v <= 0)) break;
    }
    
    return schedule;
  }

  /// 최적 인출 순서 추출
  static List<WithdrawalSource> _extractOptimalSequence(
    Map<WithdrawalSource, int> pools,
    PensionInput input,
  ) {
    final sequence = <WithdrawalSource>[];
    final nonEmptyPools = pools.entries
        .where((e) => e.value > 0)
        .map((e) => e.key)
        .toList();
    
    // 세율 기준 정렬
    nonEmptyPools.sort((a, b) {
      return _getTaxRate(a, input.currentAge)
          .compareTo(_getTaxRate(b, input.currentAge));
    });
    
    return nonEmptyPools;
  }

  /// 출처별 세율 반환
  static double _getTaxRate(WithdrawalSource source, int age) {
    switch (source) {
      case WithdrawalSource.isaProfit:
      case WithdrawalSource.isaPrincipal:
      case WithdrawalSource.pensionNonDeducted:
        return 0;
      case WithdrawalSource.pensionDeducted:
      case WithdrawalSource.irpSelf:
      case WithdrawalSource.earnings:
        return TaxCalculator.getPensionTaxRate(age);
      case WithdrawalSource.irpRetirement:
        // 퇴직소득세 (30% 감면 후) 평균 약 3.5% 가정
        return 0.035;
    }
  }
}
