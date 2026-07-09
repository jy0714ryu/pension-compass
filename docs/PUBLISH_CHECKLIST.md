# 연금나침반 게시 체크리스트 (2026-07-09)

## ✅ 완료 (코드 준비)

- [x] 인출 시뮬레이터 v2 (복리·1,500만 절벽·수령한도·4전략 토너먼트) — 테스트 25/25
- [x] 앱 표시명 한글화: 런처 "연금나침반" (Android `android:label`, iOS `CFBundleDisplayName`)
- [x] AdMob 재활성화: `google_mobile_ads ^9.0.0` (⚠️ 5.3.1은 이 프로젝트 Gradle 9.1/AGP 9.0.1에서 빌드 불가 확인)
  - 전면 광고: 계산 3회당 1회 / 적응 배너: 홈·결과 하단
  - App ID (AndroidManifest): `ca-app-pub-7975666616683761~8296037385`
  - **debug/기본값 = Google 테스트 광고 ID** — 실 광고는 릴리스 빌드에 `--dart-define` 주입 필요 (아래)
- [x] 릴리스 서명: `android/upload-keystore.jks` + `key.properties` 존재
  - ⚠️ **업로드 키 = 공시한줄(gongsi-hanjul)과 공유** (SHA1 `47:6F:30:8C:...`, 대장님 승인 2026-07-09).
    경위: "잘못된 키"+"패키지명 gongsi여야 함" 반려 2건 진단 결과, 업로드 대상이 **공시한줄 앱 항목**이었음
    (연금나침반 항목 부재). 해결=Play Console에 연금나침반 앱 항목 신규 생성 후 업로드.
    독자 생성했던 키(`AC:A0:...`)는 비번 미상으로 `upload-keystore-UNUSED-ACA0.jks.bak` 보관 (미사용).
    키 백업은 데스크탑 `공시한줄_서명키_백업/`이 동일 키 커버. 분실 시 두 앱 모두 업로드 키 재설정 필요.
- [x] privacy-policy.html (`docs/`) 존재

## 🔲 대장님 액션 (순서대로)

### 1. AdMob 콘솔 — 광고 단위 2개 발급 ✅ (2026-07-09 완료)
- **전면(pension_interstitial)**: `ca-app-pub-7975666616683761/2384436395`
- **배너(pension_banner)**: `ca-app-pub-7975666616683761/3043710701`

### 2. 릴리스 빌드 (실 광고 ID 주입) ✅ (2026-07-09 완료)
```bash
cd ~/Workspace/pension-compass/app
flutter build appbundle --release \
  --dart-define=ADMOB_INTERSTITIAL_AD_UNIT_ID=ca-app-pub-7975666616683761/2384436395 \
  --dart-define=ADMOB_BANNER_AD_UNIT_ID=ca-app-pub-7975666616683761/3043710701
# 산출물: build/app/outputs/bundle/release/app-release.aab (Play 업로드용)
# 실기기 테스트용 apk도 동일 --dart-define으로 build apk --release
```

### 3. 실기기 스모크 테스트 ✅ (2026-07-09 완료 — 갤럭시 S25 / Android 16)
**기동 크래시 발견·해결** (commit dd52da7): "Android 16 호환성 문제"의 실체 =
play-services-ads 25.x WorkManager 초기화 vs ①transitive 화석 버전(work 2.7.0/room 2.2.5)
②R8이 Room `WorkDatabase_Impl` 기본 생성자 strip → 2중 원인. work-runtime 2.10.1 강제 +
proguard keep 규칙으로 해결. adb E2E 검증:
- [x] 앱 기동·면책 다이얼로그·예시 입력·계산·결과 화면 정상 (절감 1,009만원/53.7% 표시)
- [x] 수익률 4% 입력 필드 정상
- [x] 하단 배너 **실광고 송출 확인** (분실보호·G마켓 로테이션)
- [ ] 계산 3회 시 전면 광고 (미확인 — 게시 전 선택 확인)
- [ ] 전액 비과세 + 수익률 0% 입력 → 결과 화면 정상 (단위테스트론 커버됨, 실기기 선택 확인)

### 4. Play Console 등록
- 앱 이름: **연금나침반: ISA·IRP 연금저축 인출 세금 계산기** (29자 — `marketing/store_listing.md` 참조)
- 짧은 설명·키워드: `marketing/store_listing.md`
- 개인정보처리방침 URL: `docs/privacy-policy.html`을 호스팅 필요 (GitHub Pages 권장:
  repo Settings → Pages → main/docs 지정 → `https://jy0714ryu.github.io/pension-compass/privacy-policy.html`)
- 스크린샷: 홈 입력 화면 + 결과 화면(절감 카드·차트) 최소 2장 (폰에서 캡처)
- 데이터 보안 양식: 수집 데이터 없음(온디바이스) + AdMob 광고 ID 수집 신고
- app-ads.txt: AdMob 요구 시 gongsi-hanjul의 `docs/APP_ADS_TXT_SETUP.md` 절차 재사용
- 콘텐츠 등급 설문 + 금융 앱 고지: "투자 자문 아님" 면책 명시 (앱 내 disclaimer_dialog 이미 존재)

### 5. 프로덕션 직행 (사업자 계정 — 비공개 테스트 면제)
12명·14일 비공개 테스트 요건은 2023-11-13 이후 생성된 **개인** 계정에만 적용 — 사업자(조직) 계정은 면제.
→ aab 업로드 → 프로덕션 트랙 제출. 신규 앱 첫 심사는 통상 수일 소요.
(선택) 심사 대기 중 리스크 줄이려면 내부 테스트 트랙에 같은 aab를 올려 본인 폰으로 먼저 확인 가능.

## 알려진 한계 (v2 후속 백로그)

- latentTax가 1,500만 절벽 미반영 근사 → 초대형 잔액에서 과세이연 전략 편향 가능 (P1)
- 종합과세 선택 미계산 (16.5% 보수 가정, UI 고지로 방어)
- iOS 배포 시 `GADApplicationIdentifier`(iOS용 AdMob App ID) Info.plist 추가 필요
- 전략 비교 표 UI (데이터는 `SimulationResult.outcomes`에 이미 있음)
