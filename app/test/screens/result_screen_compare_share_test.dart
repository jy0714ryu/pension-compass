import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pension_compass/models/pension_input.dart';
import 'package:pension_compass/providers/pension_provider.dart';
import 'package:pension_compass/screens/result_screen.dart';

/// v1.2 — 전략 비교표 + 이미지 공유 위젯 테스트.
void main() {
  // 과세재원이 있어 전략 간 세금 차이(절감액 > 0)가 나는 입력
  const taxableInput = PensionInput(
    pensionSavings: 100000000,
    pensionSavingsDeducted: 100000000,
    irpBalance: 50000000,
    irpRetirementPortion: 40000000,
    isaMaturity: 30000000,
    isaProfit: 5000000,
    currentAge: 58,
    targetAnnualWithdrawal: 24000000,
    simulationYears: 10,
    expectedReturnRate: 0.04,
  );

  // 전액 비과세(비공제분) — 어떤 전략이든 세금 0 → 절감액 0
  const taxFreeInput = PensionInput(
    pensionSavings: 100000000,
    pensionSavingsDeducted: 0,
    irpBalance: 0,
    irpRetirementPortion: 0,
    isaMaturity: 0,
    currentAge: 58,
    targetAnnualWithdrawal: 24000000,
    simulationYears: 10,
    expectedReturnRate: 0,
  );

  Future<void> pumpResultScreen(
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
  }

  group('전략 비교표', () {
    testWidgets('4개 전략이 모두 표시되고 우승 전략에 🏆 마크가 붙는다', (tester) async {
      await pumpResultScreen(tester, taxableInput);

      await tester.scrollUntilVisible(find.text('전략 비교'), 400);
      expect(find.text('전략 비교'), findsOneWidget);
      expect(find.text('총 부담'), findsOneWidget);
      // 4개 전략 행 — 우승 전략은 🏆 접두가 붙어 원래 이름과 합쳐진다
      const names = ['저율한도 채우기', '비과세 우선', '과세 이연 (노년 저세율)', '기존 방식 (연금저축부터)'];
      var trophyCount = 0;
      for (final n in names) {
        final plain = find.text(n).evaluate().length;
        final trophy = find.text('🏆 $n').evaluate().length;
        expect(plain + trophy, greaterThanOrEqualTo(1), reason: '$n 행 누락');
        trophyCount += trophy;
      }
      expect(trophyCount, 1, reason: '우승 전략은 정확히 1개');
    });
  });

  group('이미지 공유', () {
    testWidgets('공유 다이얼로그에 이미지 공유 버튼이 있다 (추후 예정 토스트 제거)', (tester) async {
      // 실기기 비율 뷰포트 — 기본 800×600에서는 공유 시트 내용이 오버플로된다
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await pumpResultScreen(tester, taxableInput);

      await tester.tap(find.byIcon(Icons.share).first);
      await tester.pumpAndSettle();

      expect(find.text('이미지 공유'), findsOneWidget);
      expect(find.text('텍스트 복사'), findsOneWidget);
      expect(find.textContaining('추후 업데이트 예정'), findsNothing);
    });
  });

  group('절감 0원 카드 카피', () {
    testWidgets('전액 비과세 입력이면 "0만원 절감!" 대신 긍정 카피가 나온다', (tester) async {
      await pumpResultScreen(tester, taxFreeInput);

      expect(find.text('이미 최적 인출 순서입니다'), findsOneWidget);
      // 공유 카드의 "절감!" 대형 카피는 사라져야 한다 ('0만원'은 절감 효과
      // 카드의 최적/기존 수치로 정상 존재하므로 카피 부재로만 판정)
      expect(find.text('절감!'), findsNothing);
    });

    testWidgets('절감액이 있으면 기존 절감 카피 유지', (tester) async {
      await pumpResultScreen(tester, taxableInput);

      expect(find.text('절감!'), findsOneWidget);
      expect(find.text('이미 최적 인출 순서입니다'), findsNothing);
    });
  });
}
