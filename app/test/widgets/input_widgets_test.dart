import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pension_compass/widgets/input_widgets.dart';

/// v1.1.1 감사 C1 — AmountInputField 상태/표시 불일치 회귀 테스트.
///
/// 기존 didUpdateWidget 의 `contains` 비교는 외부 state 가 0으로 리셋되거나
/// clamp 될 때 컨트롤러 텍스트를 갱신하지 못했다: 화면엔 이전 금액이 남고
/// 계산은 0으로 수행 → 세금 과소 표시. 파싱값 비교로 수정.
void main() {
  /// provider 역할의 외부 state 를 흉내내는 호스트 위젯
  Widget host({
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: AmountInputField(
          label: '테스트 금액',
          value: value,
          onChanged: onChanged,
        ),
      ),
    );
  }

  testWidgets('외부 state 가 0으로 리셋되면 표시 텍스트도 비워진다 (C1 핵심)', (tester) async {
    var state = 80000000; // 8,000만원
    await tester.pumpWidget(host(value: state, onChanged: (v) => state = v));
    expect(find.text('8,000'), findsOneWidget);

    // 외부(provider 연쇄 조정)에서 0으로 리셋 — 재빌드
    state = 0;
    await tester.pumpWidget(host(value: state, onChanged: (v) => state = v));

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, '', reason: 'state=0인데 화면에 8,000 잔존 (C1)');
  });

  testWidgets('외부 clamp 로 값이 줄면 화면도 clamp 값으로 갱신된다', (tester) async {
    var state = 80000000;
    await tester.pumpWidget(host(value: state, onChanged: (v) => state = v));

    // provider 가 잔액 한도로 clamp (8,000만 → 3,000만) 후 재빌드
    state = 30000000;
    await tester.pumpWidget(host(value: state, onChanged: (v) => state = v));

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, '3,000');
  });

  testWidgets('부분문자열 케이스: 800→80 축소도 반영된다', (tester) async {
    var state = 8000000; // 800만
    await tester.pumpWidget(host(value: state, onChanged: (v) => state = v));
    expect(find.text('800'), findsOneWidget);

    state = 800000; // 80만 — '800'.contains('80')이라 구버전은 갱신 스킵
    await tester.pumpWidget(host(value: state, onChanged: (v) => state = v));

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, '80');
  });

  testWidgets('사용자 타이핑은 state 와 일치하는 동안 덮어쓰지 않는다', (tester) async {
    var state = 0;
    late StateSetter rebuild;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return AmountInputField(
                label: '테스트 금액',
                value: state,
                onChanged: (v) => setState(() => state = v),
              );
            },
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '1234');
    rebuild(() {});
    await tester.pump();

    expect(state, 12340000); // 1,234만원 → 원 단위
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, '1,234'); // 천단위 포맷 유지, 클로버 없음
  });
}
