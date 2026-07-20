import 'pension_input.dart';

/// 저장된 시나리오 (v1.2 — 시나리오 저장·비교)
///
/// **입력값만 저장**한다 — 결과는 결정적 엔진이 즉시 재계산하므로 저장하지
/// 않는다 (세법 상수가 업데이트되면 옛 결과가 아니라 최신 기준으로 다시 계산
/// 되는 것이 올바른 동작이기도 하다).
class SavedScenario {
  /// 사용자 지정 이름 (예: "60세 은퇴·월 200") — 목록 내 유일 키
  final String name;

  /// 저장 시각 (ISO-8601)
  final String savedAt;

  final PensionInput input;

  const SavedScenario({
    required this.name,
    required this.savedAt,
    required this.input,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'savedAt': savedAt,
        'input': input.toJson(),
      };

  factory SavedScenario.fromJson(Map<String, dynamic> json) {
    return SavedScenario(
      name: json['name'] as String? ?? '이름 없음',
      savedAt: json['savedAt'] as String? ?? '',
      input: PensionInput.fromJson(
        (json['input'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
    );
  }

  /// 기본 이름 제안: "58세·월 200만원"
  static String suggestName(PensionInput input) {
    final monthly = (input.targetAnnualWithdrawal / 12 / 10000).round();
    return '${input.currentAge}세·월 $monthly만원';
  }
}
