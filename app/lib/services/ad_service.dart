import 'package:flutter/foundation.dart';

class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  Future<void> initialize() async {
    debugPrint('📢 AdMob disabled (Android 16 compatibility)');
  }

  Future<void> showInterstitialIfEligible() async {}
  void dispose() {}
}
