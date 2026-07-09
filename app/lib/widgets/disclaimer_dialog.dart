import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// 면책조항 다이얼로그 위젯
class DisclaimerDialog extends StatelessWidget {
  final VoidCallback onAccept;

  const DisclaimerDialog({super.key, required this.onAccept});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 아이콘
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.warning.withAlpha(26),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Icon(
                Icons.gavel,
                color: AppColors.warning,
                size: 32,
              ),
            ),
            const SizedBox(height: 20),
            
            // 제목
            const Text(
              '이용 전 확인사항',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            
            // 면책조항 내용
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.gray100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DisclaimerItem(
                    icon: Icons.info_outline,
                    text: '본 앱의 시뮬레이션 결과는 현재 세법 기준의 추정치이며, 실제 부과되는 세금과 다를 수 있습니다.',
                  ),
                  SizedBox(height: 12),
                  _DisclaimerItem(
                    icon: Icons.account_balance,
                    text: '정확한 세무 상담은 세무사 및 금융기관과 진행하시기 바랍니다.',
                  ),
                  SizedBox(height: 12),
                  _DisclaimerItem(
                    icon: Icons.warning_amber,
                    text: '본 앱은 투자 권유가 아니며, 투자 결정은 본인의 판단과 책임 하에 이루어져야 합니다.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // 동의 버튼
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onAccept,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '확인했습니다',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DisclaimerItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _DisclaimerItem({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.gray600),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.gray600,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}
