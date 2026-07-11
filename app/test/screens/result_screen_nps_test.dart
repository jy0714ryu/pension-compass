import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pension_compass/models/pension_input.dart';
import 'package:pension_compass/providers/pension_provider.dart';
import 'package:pension_compass/screens/result_screen.dart';

/// v1.1 Task 6 — 결과 화면 내러티브·건보료·크레바스 위젯 테스트.
void main() {
  const baseInput = PensionInput(
    pensionSavings: 100000000,
    pensionSavingsDeducted: 0,
    irpBalance: 0,
    irpRetirementPortion: 0,
    isaMaturity: 0,
    currentAge: 58,
    targetAnnualWithdrawal: 24000000,
    simulationYears: 10,
    expectedReturnRate: 0.04,
  );

  Future<ProviderContainer> pumpResultScreen(
    WidgetTester tester,
    PensionInput input,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(pensionInputProvider.notifier).loadFromStorage(input);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ResultScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  group('①hasNps=false — 내러티브만 표시, 건보료/크레바스 카드는 없다', () {
    testWidgets('내러티브 헤더가 표시되고 건보료·크레바스 관련 위젯은 렌더링되지 않는다',
        (tester) async {
      await pumpResultScreen(tester, baseInput);

      // 내러티브: 완주("N년간 쓸 수 있습니다") 또는 고갈 문구 중 하나가 항상 있어야 한다.
      final hasFundedHeadline =
          find.textContaining('년간 쓸 수 있습니다').evaluate().isNotEmpty;
      final hasDepletedHeadline =
          find.textContaining('자산이').evaluate().isNotEmpty;
      expect(hasFundedHeadline || hasDepletedHeadline, true);

      // hasNps=false이므로 건보료·크레바스 요소는 부재해야 한다.
      expect(find.text('국민연금 개시 후 건강보험료'), findsNothing);
      expect(find.textContaining('연금계좌(연금저축·IRP) 인출은 건보료에'),
          findsNothing);
      expect(find.text('개시연령'), findsNothing);
      expect(find.text('국민연금은 세금 계산에 미반영'), findsNothing);
    });
  });

  group('②hasNps=true — 건보료 카드·킬러 메시지·디스클레이머 표시', () {
    testWidgets('건보료 카드와 킬러 메시지, 상시 디스클레이머가 렌더링된다', (tester) async {
      final input = baseInput.copyWith(
        currentAge: 65,
        npsMonthlyAmount: 700000, // 월 70만 → 연 840만 (피부양자 기준 미만)
        npsStartAge: 65,
      );
      await pumpResultScreen(tester, input);

      expect(find.text('국민연금 개시 후 건강보험료'), findsOneWidget);
      expect(
        find.textContaining('연금계좌(연금저축·IRP) 인출은 현재 기준 건강보험료 부과 소득에 포함되지 않습니다'),
        findsOneWidget,
      );
      expect(
        find.text('재산(부동산 등) 기준분을 제외한 소득 기준 추정치입니다.'),
        findsOneWidget,
      );
      // 미부양 경계 미만이므로 경고 배지는 없어야 한다.
      expect(find.textContaining('피부양자 자격 상실 기준(소득 기준)에 해당'), findsNothing);
      // 국민연금 세금 미반영 팁 카드도 표시된다.
      expect(find.text('국민연금은 세금 계산에 미반영'), findsOneWidget);
    });
  });

  group('③피부양자 경계 — 월 167만원(연 2,004만원) 이상이면 경고 배지 표시', () {
    testWidgets('연소득이 2,000만원을 초과하면 피부양자 자격 상실 경고가 뜬다', (tester) async {
      final input = baseInput.copyWith(
        currentAge: 65,
        npsMonthlyAmount: 1670000, // 월 167만 → 연 2,004만 (경계 초과)
        npsStartAge: 65,
      );
      await pumpResultScreen(tester, input);

      expect(
        find.textContaining('피부양자 자격 상실 기준(소득 기준)에 해당'),
        findsOneWidget,
      );
    });

    testWidgets('연소득이 2,000만원 이하면 경고 배지가 뜨지 않는다', (tester) async {
      final input = baseInput.copyWith(
        currentAge: 65,
        npsMonthlyAmount: 1000000, // 월 100만 → 연 1,200만 (경계 미만)
        npsStartAge: 65,
      );
      await pumpResultScreen(tester, input);

      expect(
        find.textContaining('피부양자 자격 상실 기준(소득 기준)에 해당'),
        findsNothing,
      );
    });
  });
}
