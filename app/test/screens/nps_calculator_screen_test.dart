import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pension_compass/screens/nps_calculator_screen.dart';
import 'package:pension_compass/services/nps_estimator.dart';

void main() {
  final formatter = NumberFormat('#,###');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: NpsCalculatorScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> enterBaseInputs(WidgetTester tester) async {
    final fields = find.byType(TextField);
    // 순서: 월소득(만원 단위) → 가입기간(년) → 출생연도
    await tester.enterText(fields.at(0), '300'); // 300만원 = 3,000,000원
    await tester.enterText(fields.at(1), '20'); // 20년 = 240개월
    await tester.enterText(fields.at(2), '1970');
    await tester.pumpAndSettle();
  }

  group('NpsCalculatorScreen — 입력 즉시 결과 표시', () {
    testWidgets('월소득·가입기간·출생연도를 입력하면 월 예상수령액이 바로 표시된다',
        (tester) async {
      await pumpScreen(tester);

      // 입력 전: 플레이스홀더만 존재
      expect(find.textContaining('입력하면'), findsOneWidget);

      await enterBaseInputs(tester);

      final expected = NpsEstimator.estimate(const NpsEstimateInput(
        monthlyIncome: 3000000,
        enrollmentMonths: 240,
        birthYear: 1970,
        receiptType: NpsReceiptType.normal,
      ));

      expect(
        find.text('${formatter.format(expected.monthlyPensionAmount)}원'),
        findsWidgets,
      );
      expect(
        find.text('수급 개시연령: ${expected.actualStartAge}세'),
        findsOneWidget,
      );
      // 정확값 우회로 넛지 버튼 노출 확인
      expect(find.textContaining('공단 조회값 직접 입력'), findsOneWidget);
      // auto-fill 버튼 노출 확인
      expect(find.text('이 값으로 인출 설계까지 해보기 →'), findsOneWidget);
    });

    testWidgets('조기수령은 정상 대비 -30%, 연기수령은 +36% 로 계산되어 비교행에 함께 표시된다',
        (tester) async {
      await pumpScreen(tester);
      await enterBaseInputs(tester);

      const normalInput = NpsEstimateInput(
        monthlyIncome: 3000000,
        enrollmentMonths: 240,
        birthYear: 1970,
        receiptType: NpsReceiptType.normal,
      );
      final normal = NpsEstimator.estimate(normalInput);
      final early = NpsEstimator.estimate(NpsEstimateInput(
        monthlyIncome: normalInput.monthlyIncome,
        enrollmentMonths: normalInput.enrollmentMonths,
        birthYear: normalInput.birthYear,
        receiptType: NpsReceiptType.early,
        offsetYears: 5,
      ));
      final deferred = NpsEstimator.estimate(NpsEstimateInput(
        monthlyIncome: normalInput.monthlyIncome,
        enrollmentMonths: normalInput.enrollmentMonths,
        birthYear: normalInput.birthYear,
        receiptType: NpsReceiptType.deferred,
        offsetYears: 5,
      ));

      // 산식 관계 자체를 로직 레벨에서 검증 (조기 -30%, 연기 +36%, 오차 1원 이내)
      expect(
        early.monthlyPensionAmount,
        closeTo(normal.monthlyPensionAmount * 0.7, 1),
      );
      expect(
        deferred.monthlyPensionAmount,
        closeTo(normal.monthlyPensionAmount * 1.36, 1),
      );
      expect(early.actualStartAge, normal.actualStartAge - 5);
      expect(deferred.actualStartAge, normal.actualStartAge + 5);

      // 화면 비교행에 3값이 모두 노출되는지 확인 (선택 여부와 무관하게 항상 계산)
      expect(
        find.text('${formatter.format(early.monthlyPensionAmount)}원'),
        findsOneWidget,
      );
      expect(
        find.text('${formatter.format(normal.monthlyPensionAmount)}원'),
        findsWidgets,
      );
      expect(
        find.text('${formatter.format(deferred.monthlyPensionAmount)}원'),
        findsOneWidget,
      );
    });

    testWidgets('넛지 버튼을 누르면 결과값 대신 직접 입력 필드로 전환된다', (tester) async {
      await pumpScreen(tester);
      await enterBaseInputs(tester);

      final nudgeButton = find.textContaining('공단 조회값 직접 입력');
      await tester.ensureVisible(nudgeButton);
      await tester.pumpAndSettle();
      await tester.tap(nudgeButton);
      await tester.pumpAndSettle();

      expect(find.text('간이 추정값으로 되돌리기'), findsOneWidget);
    });
  });
}
