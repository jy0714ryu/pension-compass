import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pension_compass/main.dart';
import 'package:pension_compass/models/pension_input.dart';
import 'package:pension_compass/providers/pension_provider.dart';

void main() {
  setUp(() {
    // 면책조항 동의 완료 상태로 미리 설정 — 다이얼로그가 뜨면 카드 탭이 막힌다.
    SharedPreferences.setMockInitialValues({'disclaimer_accepted': true});
  });

  group('HomeScreen — 국민연금 5번째 카드 (기본 접힘, 미입력 시 기존 동작 100% 보존)', () {
    testWidgets('카드는 기본 접힘 상태이며 입력 필드가 보이지 않는다', (tester) async {
      await tester.pumpWidget(const ProviderScope(child: PensionCompassApp()));
      await tester.pumpAndSettle();

      expect(find.text('국민연금 (선택)'), findsOneWidget);
      expect(find.text('월 예상수령액'), findsNothing);
      expect(find.text('수급 개시연령'), findsNothing);
    });

    testWidgets('앱 최초 진입 시 PensionInput.npsMonthlyAmount/npsStartAge 는 null 이다',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const PensionCompassApp(),
        ),
      );
      await tester.pumpAndSettle();

      final input = container.read(pensionInputProvider);
      expect(input.npsMonthlyAmount, isNull);
      expect(input.npsStartAge, isNull);
      expect(input.hasNps, false);
    });

    testWidgets('카드를 펼친 뒤 값을 채우고 다시 접으면 국민연금 값이 null 로 초기화된다',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const PensionCompassApp(),
        ),
      );
      await tester.pumpAndSettle();

      // 카드 펼치기 (스크롤 하단에 위치하므로 화면에 들어오게 한 뒤 탭)
      final cardTitle = find.text('국민연금 (선택)');
      await tester.ensureVisible(cardTitle);
      await tester.pumpAndSettle();
      await tester.tap(cardTitle);
      await tester.pumpAndSettle();
      expect(find.text('월 예상수령액'), findsOneWidget);

      // auto-fill과 동일한 경로(setNps)로 값 채우기
      container.read(pensionInputProvider.notifier).setNps(700000, 65);
      await tester.pumpAndSettle();
      expect(container.read(pensionInputProvider).hasNps, true);

      // 카드 접기 — 값이 함께 리셋되어야 기존 4장 폼 동작과 100% 동일해진다
      await tester.ensureVisible(cardTitle);
      await tester.pumpAndSettle();
      await tester.tap(cardTitle);
      await tester.pumpAndSettle();

      final input = container.read(pensionInputProvider);
      expect(input.npsMonthlyAmount, isNull);
      expect(input.npsStartAge, isNull);
      expect(input.hasNps, false);
      expect(find.text('월 예상수령액'), findsNothing);
    });

    testWidgets(
        '월수령액만 입력하면 개시연령이 화면 표시 기본값(65세)과 동기화되어 hasNps=true 가 된다',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const PensionCompassApp(),
        ),
      );
      await tester.pumpAndSettle();

      // 카드를 펼치지 않아도(=개시연령 입력을 건드리지 않아도) 발생하는
      // 상태/표시 불일치를 재현: 월수령액 필드만 입력.
      container.read(pensionInputProvider.notifier).updateNpsMonthlyAmount(700000);
      await tester.pumpAndSettle();

      final input = container.read(pensionInputProvider);
      expect(input.npsMonthlyAmount, 700000);
      expect(input.npsStartAge, 65);
      expect(input.hasNps, true);
    });
  });

  group('loadExample — 국민연금 입력 보존 (E2E 실측 버그 회귀 가드)', () {
    test('nps 입력 상태에서 loadExample() → hasNps 유지 + 값 보존', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(pensionInputProvider.notifier);
      notifier.setNps(660000, 65); // 미니 계산기 auto-fill과 동일 경로
      notifier.loadExample();

      final input = container.read(pensionInputProvider);
      expect(input.hasNps, true);
      expect(input.npsMonthlyAmount, 660000);
      expect(input.npsStartAge, 65);
      // 자산 필드는 예시값으로 교체됐는지 확인 (보존이 통째 무시가 아님을 증명)
      expect(input.pensionSavings, PensionInput.example().pensionSavings);
    });

    test('nps 미입력 상태에서 loadExample() → hasNps=false 유지 (기존 동작)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(pensionInputProvider.notifier).loadExample();

      final input = container.read(pensionInputProvider);
      expect(input.hasNps, false);
      expect(input.npsMonthlyAmount, isNull);
      expect(input.npsStartAge, isNull);
    });

    testWidgets(
        'auto-fill 후 "예시 입력" 탭 → 카드 표시값과 state가 모두 국민연금 유지 (상태/표시 일치)',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const PensionCompassApp(),
        ),
      );
      await tester.pumpAndSettle();

      // auto-fill과 동일 경로로 국민연금 채움 + 카드 펼침
      container.read(pensionInputProvider.notifier).setNps(660000, 65);
      final cardTitle = find.text('국민연금 (선택)');
      await tester.ensureVisible(cardTitle);
      await tester.pumpAndSettle();
      await tester.tap(cardTitle);
      await tester.pumpAndSettle();
      expect(find.text('66'), findsOneWidget); // 월수령액 66만원 표시

      // 상단 "예시 입력" 탭 — E2E 버그 재현 지점
      await tester.tap(find.text('예시 입력'));
      await tester.pumpAndSettle();

      // state 보존
      final input = container.read(pensionInputProvider);
      expect(input.hasNps, true);
      expect(input.npsMonthlyAmount, 660000);
      expect(input.npsStartAge, 65);
      // 표시도 그대로 66 — 화면=상태 일치 (기존 버그는 표시 66 + state null)
      expect(find.text('66'), findsOneWidget);
    });
  });
}
