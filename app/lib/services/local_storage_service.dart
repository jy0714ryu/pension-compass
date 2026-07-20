import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import '../models/pension_input.dart';
import '../models/saved_scenario.dart';

/// 로컬 저장소 서비스 - 입력값 자동 저장/불러오기
class LocalStorageService {
  static const String _keyPensionSavings = 'pension_savings';
  static const String _keyPensionSavingsDeducted = 'pension_savings_deducted';
  static const String _keyIrpBalance = 'irp_balance';
  static const String _keyIrpRetirementPortion = 'irp_retirement_portion';
  static const String _keyIsaMaturity = 'isa_maturity';
  static const String _keyIsaProfit = 'isa_profit';
  static const String _keyCurrentAge = 'current_age';
  static const String _keyTargetAnnualWithdrawal = 'target_annual_withdrawal';
  static const String _keySimulationYears = 'simulation_years';
  static const String _keyIncomeLevel = 'income_level';
  static const String _keyExpectedReturnRate = 'expected_return_rate';
  static const String _keyDisclaimerAccepted = 'disclaimer_accepted';
  static const String _keyCalculationCount = 'calculation_count';
  static const String _keyReviewRequested = 'review_requested';
  static const String _keyNpsMonthlyAmount = 'nps_monthly_amount';
  static const String _keyNpsStartAge = 'nps_start_age';

  final SharedPreferences _prefs;

  LocalStorageService(this._prefs);

  /// SharedPreferences 인스턴스 생성
  static Future<LocalStorageService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return LocalStorageService(prefs);
  }

  /// 입력값 저장
  Future<void> saveInput(PensionInput input) async {
    await _prefs.setInt(_keyPensionSavings, input.pensionSavings);
    await _prefs.setInt(_keyPensionSavingsDeducted, input.pensionSavingsDeducted);
    await _prefs.setInt(_keyIrpBalance, input.irpBalance);
    await _prefs.setInt(_keyIrpRetirementPortion, input.irpRetirementPortion);
    await _prefs.setInt(_keyIsaMaturity, input.isaMaturity);
    await _prefs.setInt(_keyIsaProfit, input.isaProfit);
    await _prefs.setInt(_keyCurrentAge, input.currentAge);
    await _prefs.setInt(_keyTargetAnnualWithdrawal, input.targetAnnualWithdrawal);
    await _prefs.setInt(_keySimulationYears, input.simulationYears);
    await _prefs.setString(_keyIncomeLevel, input.incomeLevel.name);
    await _prefs.setDouble(_keyExpectedReturnRate, input.expectedReturnRate);

    // 국민연금 (선택 — null이면 저장된 값 제거해 미입력 상태로 복원)
    if (input.npsMonthlyAmount != null) {
      await _prefs.setInt(_keyNpsMonthlyAmount, input.npsMonthlyAmount!);
    } else {
      await _prefs.remove(_keyNpsMonthlyAmount);
    }
    if (input.npsStartAge != null) {
      await _prefs.setInt(_keyNpsStartAge, input.npsStartAge!);
    } else {
      await _prefs.remove(_keyNpsStartAge);
    }
  }

  /// 저장된 입력값 불러오기
  PensionInput? loadInput() {
    // 저장된 데이터가 있는지 확인
    if (!_prefs.containsKey(_keyPensionSavings)) {
      return null;
    }

    final incomeLevelStr = _prefs.getString(_keyIncomeLevel) ?? 'high';
    final incomeLevel = incomeLevelStr == 'low' ? IncomeLevel.low : IncomeLevel.high;

    return PensionInput(
      pensionSavings: _prefs.getInt(_keyPensionSavings) ?? 0,
      pensionSavingsDeducted: _prefs.getInt(_keyPensionSavingsDeducted) ?? 0,
      irpBalance: _prefs.getInt(_keyIrpBalance) ?? 0,
      irpRetirementPortion: _prefs.getInt(_keyIrpRetirementPortion) ?? 0,
      isaMaturity: _prefs.getInt(_keyIsaMaturity) ?? 0,
      isaProfit: _prefs.getInt(_keyIsaProfit) ?? 0,
      currentAge: _prefs.getInt(_keyCurrentAge) ?? 55,
      targetAnnualWithdrawal: _prefs.getInt(_keyTargetAnnualWithdrawal) ?? 24000000,
      simulationYears: _prefs.getInt(_keySimulationYears) ?? 20,
      incomeLevel: incomeLevel,
      expectedReturnRate: _prefs.getDouble(_keyExpectedReturnRate) ?? 0.04,
      npsMonthlyAmount: _prefs.containsKey(_keyNpsMonthlyAmount)
          ? _prefs.getInt(_keyNpsMonthlyAmount)
          : null,
      npsStartAge: _prefs.containsKey(_keyNpsStartAge)
          ? _prefs.getInt(_keyNpsStartAge)
          : null,
    );
  }

  /// 면책조항 동의 여부 저장
  Future<void> setDisclaimerAccepted(bool accepted) async {
    await _prefs.setBool(_keyDisclaimerAccepted, accepted);
  }

  /// 면책조항 동의 여부 확인
  bool isDisclaimerAccepted() {
    return _prefs.getBool(_keyDisclaimerAccepted) ?? false;
  }

  /// 계산 횟수 증가 및 반환
  Future<int> incrementCalculationCount() async {
    final count = (_prefs.getInt(_keyCalculationCount) ?? 0) + 1;
    await _prefs.setInt(_keyCalculationCount, count);
    return count;
  }

  /// 현재 계산 횟수
  int getCalculationCount() {
    return _prefs.getInt(_keyCalculationCount) ?? 0;
  }

  /// 리뷰 요청 여부 저장
  Future<void> setReviewRequested(bool requested) async {
    await _prefs.setBool(_keyReviewRequested, requested);
  }

  /// 리뷰 요청 여부 확인
  bool isReviewRequested() {
    return _prefs.getBool(_keyReviewRequested) ?? false;
  }

  // ── 시나리오 저장·비교 (v1.2) ─────────────────────────────────────────

  static const String _keySavedScenarios = 'saved_scenarios';

  /// 저장 가능한 시나리오 최대 개수
  static const int maxScenarios = 5;

  /// 저장된 시나리오 목록 (최신 저장 순)
  List<SavedScenario> loadScenarios() {
    final raw = _prefs.getString(_keySavedScenarios);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) =>
              SavedScenario.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return const []; // 손상 데이터는 빈 목록으로 (앱 크래시 방지)
    }
  }

  /// 시나리오 저장 — 같은 이름은 교체, 초과 시 false 반환 (저장 안 함)
  Future<bool> saveScenario(SavedScenario scenario) async {
    final list = List<SavedScenario>.from(loadScenarios())
      ..removeWhere((s) => s.name == scenario.name);
    if (list.length >= maxScenarios) return false;
    list.insert(0, scenario);
    await _prefs.setString(
      _keySavedScenarios,
      jsonEncode(list.map((s) => s.toJson()).toList()),
    );
    return true;
  }

  /// 시나리오 삭제
  Future<void> deleteScenario(String name) async {
    final list = List<SavedScenario>.from(loadScenarios())
      ..removeWhere((s) => s.name == name);
    await _prefs.setString(
      _keySavedScenarios,
      jsonEncode(list.map((s) => s.toJson()).toList()),
    );
  }
}
