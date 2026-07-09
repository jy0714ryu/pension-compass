# 연금나침반 게시 체크리스트 (2026-07-09)

## ✅ 완료 (코드 준비)

- [x] 인출 시뮬레이터 v2 (복리·1,500만 절벽·수령한도·4전략 토너먼트) — 테스트 25/25
- [x] 앱 표시명 한글화: 런처 "연금나침반" (Android `android:label`, iOS `CFBundleDisplayName`)
- [x] AdMob 재활성화: `google_mobile_ads ^9.0.0` (⚠️ 5.3.1은 이 프로젝트 Gradle 9.1/AGP 9.0.1에서 빌드 불가 확인)
  - 전면 광고: 계산 3회당 1회 / 적응 배너: 홈·결과 하단
  - App ID (AndroidManifest): `ca-app-pub-7975666616683761~8296037385`
  - **debug/기본값 = Google 테스트 광고 ID** — 실 광고는 릴리스 빌드에 `--dart-define` 주입 필요 (아래)
- [x] 릴리스 서명: `android/upload-keystore.jks` + `key.properties` 존재
- [x] privacy-policy.html (`docs/`) 존재

## 🔲 대장님 액션 (순서대로)

### 1. AdMob 콘솔 — 광고 단위 2개 발급
[AdMob 콘솔](https://apps.admob.com) → 연금나침반 앱 → 광고 단위 추가:
- **전면(Interstitial)** 1개 → ID 복사 (`ca-app-pub-7975666616683761/XXXXXXXXXX`)
- **배너(Banner)** 1개 → ID 복사

### 2. 릴리스 빌드 (실 광고 ID 주입)
```bash
cd ~/Workspace/pension-compass/app
flutter build appbundle --release \
  --dart-define=ADMOB_INTERSTITIAL_AD_UNIT_ID=ca-app-pub-7975666616683761/전면ID \
  --dart-define=ADMOB_BANNER_AD_UNIT_ID=ca-app-pub-7975666616683761/배너ID
# 산출물: build/app/outputs/bundle/release/app-release.aab
```

### 3. 실기기 스모크 테스트 (⚠️ 필수 — Android 16 폰)
과거 "Android 16 호환성 문제" 메모가 빌드 문제였는지 런타임 문제였는지 불명.
9.0.0으로 빌드는 검증됐으나 **실기기 런타임 확인 필요**:
```bash
flutter build apk --release --dart-define=... (위와 동일) && flutter install
```
- [ ] 앱 기동·계산·결과 화면 정상
- [ ] 하단 배너 표시 (릴리스 빌드 실 ID → 게시 전엔 노출 안 될 수 있음, 크래시만 없으면 OK)
- [ ] 계산 3회 시 전면 광고 (또는 무광고 스킵) 크래시 없음
- [ ] **전액 비과세 + 수익률 0% 입력 → 결과 화면 정상** (리뷰에서 잡은 크래시 수정 검증)

### 4. Play Console 등록
- 앱 이름: **연금나침반: ISA·IRP 연금저축 인출 세금 계산기** (29자 — `marketing/store_listing.md` 참조)
- 짧은 설명·키워드: `marketing/store_listing.md`
- 개인정보처리방침 URL: `docs/privacy-policy.html`을 호스팅 필요 (GitHub Pages 권장:
  repo Settings → Pages → main/docs 지정 → `https://jy0714ryu.github.io/pension-compass/privacy-policy.html`)
- 스크린샷: 홈 입력 화면 + 결과 화면(절감 카드·차트) 최소 2장 (폰에서 캡처)
- 데이터 보안 양식: 수집 데이터 없음(온디바이스) + AdMob 광고 ID 수집 신고
- app-ads.txt: AdMob 요구 시 gongsi-hanjul의 `docs/APP_ADS_TXT_SETUP.md` 절차 재사용
- 콘텐츠 등급 설문 + 금융 앱 고지: "투자 자문 아님" 면책 명시 (앱 내 disclaimer_dialog 이미 존재)

### 5. 비공개 테스트 → 프로덕션
Play 신규 개인 계정은 프로덕션 전 **비공개 테스트(테스터 12명·14일)** 요건 있음 — gongsi-hanjul과 동일 절차.

## 알려진 한계 (v2 후속 백로그)

- latentTax가 1,500만 절벽 미반영 근사 → 초대형 잔액에서 과세이연 전략 편향 가능 (P1)
- 종합과세 선택 미계산 (16.5% 보수 가정, UI 고지로 방어)
- iOS 배포 시 `GADApplicationIdentifier`(iOS용 AdMob App ID) Info.plist 추가 필요
- 전략 비교 표 UI (데이터는 `SimulationResult.outcomes`에 이미 있음)
