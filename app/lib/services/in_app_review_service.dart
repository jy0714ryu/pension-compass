import 'package:in_app_review/in_app_review.dart';
import 'local_storage_service.dart';

/// 인앱 리뷰 서비스
class InAppReviewService {
  final InAppReview _inAppReview = InAppReview.instance;
  final LocalStorageService _storage;

  /// 리뷰 요청 조건: 최소 계산 횟수
  static const int _minCalculationCount = 3;

  /// 리뷰 요청 조건: 최소 절감액 (원)
  static const int _minSavingsAmount = 100000; // 10만원

  InAppReviewService(this._storage);

  /// 리뷰 요청 가능 여부 확인 및 요청
  /// 
  /// [savingsAmount] 절감액 (원)
  Future<void> requestReviewIfEligible(int savingsAmount) async {
    // 이미 리뷰 요청한 적 있으면 스킵
    if (_storage.isReviewRequested()) {
      return;
    }

    // 계산 횟수 확인
    final calculationCount = _storage.getCalculationCount();
    if (calculationCount < _minCalculationCount) {
      return;
    }

    // 절감액 확인
    if (savingsAmount < _minSavingsAmount) {
      return;
    }

    // 인앱 리뷰 가능 여부 확인
    final isAvailable = await _inAppReview.isAvailable();
    if (!isAvailable) {
      return;
    }

    // 리뷰 요청
    await _inAppReview.requestReview();

    // 리뷰 요청 완료 기록
    await _storage.setReviewRequested(true);
  }

  /// 강제 리뷰 요청 (설정 등에서 수동 호출용)
  Future<void> forceRequestReview() async {
    final isAvailable = await _inAppReview.isAvailable();
    if (isAvailable) {
      await _inAppReview.requestReview();
    }
  }
}
