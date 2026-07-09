import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pension_compass/main.dart';

void main() {
  testWidgets('앱이 정상적으로 로드됨', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: PensionCompassApp(),
      ),
    );
    
    // 앱 타이틀 확인
    expect(find.text('연금나침반'), findsOneWidget);
  });
}
