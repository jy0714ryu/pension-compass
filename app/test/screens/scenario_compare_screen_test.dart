import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pension_compass/models/pension_input.dart';
import 'package:pension_compass/models/saved_scenario.dart';
import 'package:pension_compass/providers/pension_provider.dart';
import 'package:pension_compass/screens/scenario_compare_screen.dart';
import 'package:pension_compass/services/local_storage_service.dart';

/// v1.2 — 시나리오 2-up 비교 화면 위젯 테스트.
void main() {
  const inputA = PensionInput(
    pensionSavings: 100000000,
    pensionSavingsDeducted: 100000000,
    irpBalance: 0,
    irpRetirementPortion: 0,
    isaMaturity: 0,
    currentAge: 60,
    targetAnnualWithdrawal: 24000000,
    simulationYears: 10,
    expectedReturnRate: 0.04,
  );

  Future<void> pumpCompare(
    WidgetTester tester, {
    required List<SavedScenario> saved,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final storage =
        LocalStorageService(await SharedPreferences.getInstance());
    for (final s in saved.reversed) {
      await storage.saveScenario(s);
    }
    final container = ProviderContainer(overrides: [
      savedScenariosProvider.overrideWith(
        (ref) => SavedScenariosNotifier(storage),
      ),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ScenarioCompareScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  SavedScenario scenario(String name, PensionInput input) =>
      SavedScenario(name: name, savedAt: '2026-07-20T10:00:00', input: input);

  testWidgets('시나리오 0개 — 안내 문구', (tester) async {
    await pumpCompare(tester, saved: []);
    expect(find.textContaining('저장된 시나리오가 없습니다'), findsOneWidget);
  });

  testWidgets('시나리오 2개 — 비교 표에 총 세금·인출 지속·우승 전략 행이 나온다',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await pumpCompare(tester, saved: [
      scenario('60세 은퇴', inputA),
      scenario('63세 은퇴', inputA.copyWith(currentAge: 63)),
    ]);

    expect(find.text('나란히 비교'), findsOneWidget);
    expect(find.text('총 세금 (최적)'), findsOneWidget);
    expect(find.text('인출 지속'), findsOneWidget);
    expect(find.text('우승 전략'), findsOneWidget);
    expect(find.text('A. 60세 은퇴'), findsOneWidget);
    expect(find.text('B. 63세 은퇴'), findsOneWidget);
    // 나이 행 값
    expect(find.text('60세'), findsWidgets);
    expect(find.text('63세'), findsWidgets);
  });

  testWidgets('시나리오 1개 — 2개 필요 안내', (tester) async {
    await pumpCompare(tester, saved: [scenario('하나뿐', inputA)]);
    expect(find.textContaining('서로 다른 시나리오 2개가 필요합니다'), findsOneWidget);
  });

  testWidgets('칩 X 로 삭제하면 목록에서 사라진다', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await pumpCompare(tester, saved: [
      scenario('60세 은퇴', inputA),
      scenario('63세 은퇴', inputA.copyWith(currentAge: 63)),
    ]);

    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();

    expect(find.byType(Chip), findsOneWidget);
  });
}
