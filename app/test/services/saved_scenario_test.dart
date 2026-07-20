import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pension_compass/models/pension_input.dart';
import 'package:pension_compass/models/saved_scenario.dart';
import 'package:pension_compass/services/local_storage_service.dart';

/// v1.2 — 시나리오 저장·비교: 직렬화 round-trip + 저장소 규칙.
void main() {
  const input = PensionInput(
    pensionSavings: 100000000,
    pensionSavingsDeducted: 80000000,
    irpBalance: 50000000,
    irpRetirementPortion: 40000000,
    isaMaturity: 30000000,
    isaProfit: 5000000,
    currentAge: 58,
    targetAnnualWithdrawal: 24000000,
    simulationYears: 20,
    expectedReturnRate: 0.04,
    npsMonthlyAmount: 800000,
    npsStartAge: 65,
  );

  Future<LocalStorageService> freshStorage() async {
    SharedPreferences.setMockInitialValues({});
    return LocalStorageService(await SharedPreferences.getInstance());
  }

  SavedScenario scenario(String name, [PensionInput i = input]) =>
      SavedScenario(name: name, savedAt: '2026-07-20T10:00:00', input: i);

  group('직렬화 round-trip', () {
    test('PensionInput JSON 왕복 — nps 포함 전 필드 보존', () {
      final restored = PensionInput.fromJson(input.toJson());
      expect(restored.toJson(), input.toJson());
      expect(restored.hasNps, true);
      expect(restored.npsMonthlyAmount, 800000);
    });

    test('nps null 왕복 — 미입력 상태 보존', () {
      const noNps = PensionInput(
        pensionSavings: 1,
        pensionSavingsDeducted: 0,
        irpBalance: 0,
        irpRetirementPortion: 0,
        isaMaturity: 0,
        currentAge: 60,
        targetAnnualWithdrawal: 12000000,
      );
      final restored = PensionInput.fromJson(noNps.toJson());
      expect(restored.hasNps, false);
      expect(restored.npsMonthlyAmount, null);
    });

    test('SavedScenario JSON 왕복', () {
      final s = scenario('60세 은퇴');
      final restored = SavedScenario.fromJson(s.toJson());
      expect(restored.name, '60세 은퇴');
      expect(restored.input.toJson(), input.toJson());
    });
  });

  group('저장소 규칙', () {
    test('저장 → 로드 (최신 저장이 앞)', () async {
      final storage = await freshStorage();
      await storage.saveScenario(scenario('A'));
      await storage.saveScenario(scenario('B'));
      final loaded = storage.loadScenarios();
      expect(loaded.map((s) => s.name).toList(), ['B', 'A']);
    });

    test('같은 이름은 덮어쓰기 (개수 불변)', () async {
      final storage = await freshStorage();
      await storage.saveScenario(scenario('A'));
      await storage
          .saveScenario(scenario('A', input.copyWith(currentAge: 60)));
      final loaded = storage.loadScenarios();
      expect(loaded.length, 1);
      expect(loaded.single.input.currentAge, 60);
    });

    test('최대 5개 초과 저장은 거부 (false)', () async {
      final storage = await freshStorage();
      for (var i = 0; i < LocalStorageService.maxScenarios; i++) {
        expect(await storage.saveScenario(scenario('S$i')), true);
      }
      expect(await storage.saveScenario(scenario('overflow')), false);
      expect(storage.loadScenarios().length, LocalStorageService.maxScenarios);
    });

    test('삭제 후 재저장 가능', () async {
      final storage = await freshStorage();
      for (var i = 0; i < LocalStorageService.maxScenarios; i++) {
        await storage.saveScenario(scenario('S$i'));
      }
      await storage.deleteScenario('S0');
      expect(await storage.saveScenario(scenario('new')), true);
    });

    test('손상 JSON 은 빈 목록 (크래시 방지)', () async {
      SharedPreferences.setMockInitialValues(
          {'saved_scenarios': '{broken json'});
      final storage =
          LocalStorageService(await SharedPreferences.getInstance());
      expect(storage.loadScenarios(), isEmpty);
    });
  });

  group('이름 제안', () {
    test('나이·월 인출액 기반', () {
      expect(SavedScenario.suggestName(input), '58세·월 200만원');
    });
  });
}
