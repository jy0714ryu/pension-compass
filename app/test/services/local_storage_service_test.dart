import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pension_compass/models/pension_input.dart';
import 'package:pension_compass/services/local_storage_service.dart';

void main() {
  // auto-fill 퍼널 검증: 미니 계산기가 저장한 국민연금 값이 홈 재방문(loadInput) 시
  // 그대로 복원되는지 확인한다 (v1.1 Task 5, exec-plan UI 투트랙 ③).
  group('LocalStorageService — 국민연금 auto-fill 저장/복원', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('국민연금 값이 있는 입력을 저장하면 로드 시 그대로 복원된다', () async {
      final storage = await LocalStorageService.create();
      final input = PensionInput.example().copyWith(
        npsMonthlyAmount: 700000,
        npsStartAge: 65,
      );

      await storage.saveInput(input);
      final loaded = storage.loadInput();

      expect(loaded, isNotNull);
      expect(loaded!.npsMonthlyAmount, 700000);
      expect(loaded.npsStartAge, 65);
      expect(loaded.hasNps, true);
    });

    test('국민연금 미입력 상태(null)를 저장하면 로드 시에도 null 로 복원된다', () async {
      final storage = await LocalStorageService.create();
      final input = PensionInput.example();

      await storage.saveInput(input);
      final loaded = storage.loadInput();

      expect(loaded, isNotNull);
      expect(loaded!.npsMonthlyAmount, isNull);
      expect(loaded.npsStartAge, isNull);
      expect(loaded.hasNps, false);
    });

    test('국민연금 값을 저장했다가 카드 접힘으로 리셋 후 재저장하면 null 로 되돌아간다', () async {
      final storage = await LocalStorageService.create();
      final withNps = PensionInput.example().copyWith(
        npsMonthlyAmount: 900000,
        npsStartAge: 63,
      );
      await storage.saveInput(withNps);
      expect(storage.loadInput()!.hasNps, true);

      // 카드 접힘 시 UI가 하는 것과 동일하게 새 PensionInput으로 nps 필드를 리셋.
      final cleared = PensionInput.example();
      await storage.saveInput(cleared);
      final loaded = storage.loadInput();

      expect(loaded!.npsMonthlyAmount, isNull);
      expect(loaded.npsStartAge, isNull);
    });
  });
}
