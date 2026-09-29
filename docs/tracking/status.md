# 현황

이 저장소는 2026-09-23 초기 커밋(`ae7b2cf`)으로 Chrome 확장, Flutter 앱, 공용 빌드 패키지를 한데 모았다. 같은 코드의 이전 사본이 `chrome-extension-mono`(`vibecode-chrome-extension-infocutter`)와 `flutter-app-mono`(`apps/infocutter-app`)에 남아 있다.

## 검증 기록 (2026-09-30, macOS, 커밋 `30477d0` 기준)

| 대상 | 명령 | 결과 |
|---|---|---|
| Chrome 의존성 | `npm ci` | 실패. lock 파일에 `@vibecode/ext-build` 경로가 예전 배치로 남아 있다 |
| Chrome 의존성 | `npm install` | 통과 |
| Chrome lint | `npm run pipe:lint` | 통과 |
| Chrome 타입 | `npm run pipe:typecheck` | 통과 |
| Chrome 테스트 | `npm run pipe:test` | 통과, 테스트 41개 중 41개 성공 |
| Chrome 진단 | `npm run pipe:doctor` | 통과 |
| Chrome 주석 게이트 | `bash tools/scripts/no-comments-gate.sh` | 실패. shebang 줄과 `vendor/jspdf.js`를 주석으로 오판한다. `src`·`packages/*/src`·`tests`에는 `//` 줄 주석이 없다 |
| Chrome 템플릿 서버 | `node scripts/templates-server.mjs` 불러오기 | 실패. `scripts/lib.mjs`가 없다 |
| Flutter 의존성 | `flutter pub get` (Flutter 3.44.0) | 통과 |
| Flutter 정적 분석 | `flutter analyze` | 통과, 문제 0건 |
| Flutter 테스트 | `flutter test` | 통과, 414개 성공 |
| Flutter 지표 | `dart run dart_code_linter:metrics analyze lib` | 통과, 문제 0건 |
| 주입 JS | `node tool/js_test.mjs` | 통과, 5개 성공 |
| 생성물 동기 | `generate_user_scripts.dart --check`, `generate_theme_tokens.dart --check` | 둘 다 동기 상태 |
| Dart 포맷 | `dart format --output=none --set-exit-if-changed lib test` | 실패. 304개 중 6개 파일이 바뀐다 |
| `fvm flutter` | `fvm flutter --version` | 실패. 앱에 `.fvmrc`가 없고 fvm 전역 버전이 지정되지 않은 기기였다. 위 Flutter 결과는 fvm 캐시의 stable SDK를 직접 불러 얻었다 |

돌리지 않은 것: `integration_test/infocutter_app_smoke_test.dart`(기기 필요), Android·iOS·macOS·Windows 앱 빌드, Chrome에 확장을 올린 수동 확인, `npm run pipe:safari`와 Safari 실기 로드, MCP `smoke.mjs`(실행 중인 디버그 앱 필요).

## 기능별 상태

"구현"은 코드가 있다는 뜻이고, "검증"은 위 기록의 자동 테스트가 그 동작을 덮는다는 뜻이다.

| 기능 | Chrome 확장 | Flutter 앱 |
|---|---|---|
| 선택자 규칙 저장소·정규화 | 구현, 단위 테스트로 검증 | 구현, 단위 테스트로 검증 |
| 선택 모드와 선택자 생성 | 구현. content script라 자동 테스트 없음 | 구현. picker JS는 파싱만 검사, Dart 쪽 세션 로직은 테스트 있음 |
| iframe 규칙 | 구현. 자동 테스트 없음 | JS 런타임만 부분 구현, ContentBlocker는 최상위 문서만 |
| 텍스트 블록 | 구현, 저장소 로직만 테스트 | 구현, 모델·서비스 테스트 있음 |
| 네트워크 필터 | 구현, 필터 해석·변환 테스트 있음. 실제 declarativeNetRequest 적용은 자동 테스트 없음 | 구현(WebView 수준), 서비스 테스트 있음 |
| 템플릿 | options 화면 구현. 템플릿 서버는 시작 불가 | 내장 템플릿 2종 구현 |
| 감시(watch) | 구현, 저장소·매칭 테스트 있음 | 구현, 서비스 테스트 있음 |
| 증거 저장 | 구현, PDF 빌더 단위 테스트 있음. 캡처부터 다운로드까지는 자동 테스트 없음 | 구현, 서비스 테스트 있음 |
| AI 마스킹 | 구현(수동 실행, 자동 적용), 설정·파싱·오케스트레이터 테스트 있음 | 구현(수동 실행, 승인 후 적용), 테스트 있음 |
| 인증 origin 배제 | 해당 없음 | 구현, 판정 함수 테스트 있음. 실기기 Google 로그인 제출 이후 단계는 미확인 |
| iOS Safari 확장 | 변환·Archive 스크립트 구현. 실행하지 않음 | 해당 없음 |
| 디버그 자동화 브리지·MCP | 해당 없음 | 구현. 브리지 테스트 있음, MCP 스모크는 이번에 돌리지 않음 |

## 남은 일 (우선순위 순)

1. `extensions/chrome/package-lock.json`을 현재 배치 경로로 갱신해 `npm ci`가 되게 한다.
2. service worker의 content script 재주입 목록에 `selector-rules-package.js`를 넣고, 설치 전에 열린 탭에서 선택 모드를 확인한다.
3. 정본 저장소를 하나로 정하고, README·`pubspec.yaml`·`apps/browser/.codex/AGENTS.md`·`packages/ext-build/README.md`의 옛 경로를 정리한다.
4. Chrome과 Flutter의 프로필 적용 방식(첫 프로필 하나 대 합집합, `unhide` 범위, iframe 규칙)을 하나로 맞춘다.
5. 템플릿 서버를 다시 실행 가능하게 하고, 템플릿에 `mode`를 보존한다.
6. 루트 `.github/workflows`에 머지 전 게이트를 올리거나, 실행되지 않는 하위 CI 파일을 정리한다.
7. Flutter 포맷 차이 6개 파일을 정리하고 앱에 Flutter 버전을 고정한다(`.fvmrc`).
8. Flutter `RuleStoreCodec`이 version 1·2 입력을 Chrome과 같게 읽게 한다.
9. Chrome content script용 DOM 테스트 환경을 마련한다.
10. Flutter 쪽 Chrome 대비 기능 차이(선택자 저장소, picker, iframe, 텍스트 블록, 네트워크, 템플릿, 감시, 증거, AI, 동등성 테스트 10개 영역 모두 부분 구현)를 메운다.
11. 실기기에서 Google 등 IdP 로그인 제출 이후 단계를 확인한다.

## 막힌 것

- 1~3번과 6번은 저장소 소유자가 정본 저장소와 CI 위치를 정해야 진행할 수 있다.
- 11번은 Android·iOS 실기기가 있어야 한다.
