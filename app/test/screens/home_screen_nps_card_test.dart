import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pension_compass/main.dart';
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
}
