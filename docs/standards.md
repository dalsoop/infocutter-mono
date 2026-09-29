# 표준

## 머지 전 게이트

GitHub 저장소 루트에는 워크플로가 없다. `apps/browser/.github/workflows/main.yml`과 `extensions/chrome/.gitlab-ci.yml`은 하위 디렉터리에 있어서 이 저장소에서는 실행되지 않는다. 따라서 아래 로컬 게이트가 유일한 머지 조건이다. 바꾼 쪽의 게이트를 모두 통과해야 하고, 두 쪽에 걸친 변경(규칙 JSON 모양 등)은 두 게이트를 모두 돌린다.

Chrome 확장 (`extensions/chrome`에서):

```sh
(
  set -e
  npm install
  npm run pipe:check     # eslint . → tsc --noEmit → 빌드 → node --test 'dist/tests/*.js'
  npm run pipe:doctor    # manifest·필수 권한·산출물 점검
)
```

Flutter 앱 (`apps/browser`에서, `flutter`·`dart`는 fvm이 가리키는 Flutter SDK의 것):

```sh
(
  set -e
  flutter pub get
  flutter analyze                                        # "No issues found!"여야 한다
  flutter test
  dart run dart_code_linter:metrics analyze lib           # "no issues found!"여야 한다
  node tool/js_test.mjs                                   # 주입 JS 회귀 검사
  dart run tool/generate_user_scripts.dart --check        # assets/js 와 .g.dart 동기
  dart run tool/generate_theme_tokens.dart --check        # design-tokens.json 과 .g.dart 동기
)
```

`dart format --output=none --set-exit-if-changed lib test`는 2026-09-30 기준 Flutter 3.44.0(Dart 3.12.0)에서 6개 파일 때문에 실패한다. 이 검사는 해당 파일이 정리되기 전까지 게이트에서 빠져 있다. 새로 만들거나 고친 Dart 파일은 `dart format`을 거친 상태로 커밋한다.

게이트를 돌리지 않았거나 실패했으면 "완료", "준비됨"이라고 쓰지 않는다. 실행한 명령과 결과를 커밋 본문이나 PR 설명에 남긴다.

## 브랜치와 커밋

- 기본 브랜치는 `main`이고 원격은 GitHub `dalsoop/infocutter-mono` 하나다. 작업은 브랜치에서 하고 PR로 `main`에 합친다.
- 커밋 제목은 `<type>(<scope>): <요약>` 형식을 쓴다. type은 `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `build`, `ci`, `perf`, `revert` 가운데 하나다.
- 스테이징은 경로를 지정해서 한다. `git add -A`, `git commit -a`를 쓰지 않는다.
- 런타임 의존성(`extensions/chrome/package.json`의 dependencies, `apps/browser/pubspec.yaml`의 dependencies)을 추가하면 커밋 본문에 이유를 적는다.
- `extensions/chrome/package-lock.json`, `apps/browser/pubspec.lock`은 매니페스트를 바꾼 같은 커밋에 함께 넣는다.

## 모듈 경계

- Chrome `src/background`, `src/popup`, `src/options`, `src/content`는 서로를 import하지 않는다. 공유 코드는 `src/shared`나 `extensions/chrome/packages/*`에 둔다. ESLint `no-restricted-imports`가 `../background/*`, `../popup/*`, `../content/*` import를 오류로 만든다.
- `src/content/*.ts`는 `import`·`export` 문을 쓰지 않는다. content script는 전역 스코프를 공유하는 일반 스크립트로 로드된다. 다른 content 파일이나 도메인 패키지의 기능은 전역 이름과 `src/content/contracts.d.ts`의 선언으로 쓴다.
- `extensions/chrome/packages/*/src/index.ts`는 `chrome.*` API, DOM 전역 상태, 다른 패키지를 import하지 않는 순수 모듈로 유지한다. 빌드가 이 파일의 `export`를 지워 IIFE로 감싸므로 모듈 밖 상태에 기대면 content script에서 깨진다.
- Flutter `lib/models/`는 `webview_tab.dart`, `lib/pages/`, `lib/app_bar/`를 import하지 않는다.
- Flutter 인포커터 도메인 로직(선택자, 규칙 저장소, ContentBlocker, 텍스트 블록, 감시, 증거, 네트워크 필터, AI)은 `lib/infocutter/`에 두고, 그 위젯은 `lib/infocutter/ui/`에 둔다. `lib/pages/`, `lib/app_bar/`, `lib/main.dart`에 도메인 판정 로직을 새로 넣지 않는다.
- `lib/main.dart`는 부트스트랩 밖에서 import하지 않는다.

## 단일 위치 규칙

| 대상 | 유일한 위치 |
|---|---|
| Chrome 선택자 규칙 모델·정규화·매칭 | `extensions/chrome/packages/infocutter-selector-rules/src/index.ts` |
| Chrome 텍스트 블록·감시 모델 | `packages/infocutter-text-blocks`, `packages/infocutter-watch` (둘 다 `extensions/chrome` 아래) |
| Chrome 필터 목록 해석 | `extensions/chrome/packages/infocutter-filter-importer/src/index.ts` |
| Chrome 메시지 타입 이름 | `infocutterMessageTypes` (선택자 규칙 패키지) |
| Flutter 인증 origin 판정 | `lib/infocutter/auth_origin_policy.dart`의 `isAuthOrigin` |
| Flutter 규칙 JSON 인코딩·디코딩 | `lib/infocutter/rule_store_codec.dart`의 `RuleStoreCodec` |
| Flutter ContentBlocker 생성(선택자) | `lib/infocutter/content_blocker_factory.dart` |
| Flutter 선택자 생성·검증 | `lib/infocutter/selector_engine.dart` |
| Flutter 규칙 저장소 키 | `lib/infocutter/storage.dart` |
| WebView 주입 JS 원본 | `apps/browser/assets/js/*.js` (`lib/infocutter/generated/user_scripts.g.dart`는 생성물) |
| Flutter 색·간격·radius | `apps/browser/design/design-tokens.json` (`lib/theme/infocutter_tokens.g.dart`는 생성물) |

같은 판정을 다른 파일에 새로 구현하지 않는다. 위반 기준은 "위 표의 대상과 같은 일을 하는 함수가 다른 파일에 새로 생겼는가"다.

## 저장소 스키마

- 모든 영속 저장소 값은 `version` 필드를 가진다. 버전 없는 새 저장소 키를 만들지 않는다.
- 스키마를 바꾸면 `version`을 올리고, 이전 버전 입력을 새 모양으로 바꾸는 분기를 normalize(Chrome)나 codec(Flutter)에 넣고, 이전 버전 JSON을 입력으로 쓰는 테스트를 추가한다.
- 선택자 규칙 저장소 모양을 바꾸면 Chrome `normalizeRuleStore`, Chrome content 쪽 `src/content/site-storage.ts`, Flutter `RuleStoreCodec`을 같은 변경에서 고친다.
- 저장소 키 이름(`infocutter.ruleStore`, `infocutter.textBlockStore`, `infocutter.networkRuleStore`, `infocutter.watchStore`, `infocutter.aiRuleStore`, `infocutter.aiConfig`)은 바꾸지 않는다. 바꾸면 기존 사용자 데이터가 읽히지 않는다.

## Chrome 확장 코드 규칙

- `innerHTML`, `eval`, `new Function`, 원격 코드 로드를 쓰지 않는다.
- `console.log`를 남기지 않는다. `console.warn`, `console.error`만 허용한다(ESLint `no-console`).
- `any`를 쓰지 않는다. 떠 있는 Promise는 `void`로 명시하거나 `await`한다(ESLint `no-floating-promises`).
- TypeScript·JavaScript 파일에 `//`로 시작하는 줄 주석을 쓰지 않는다. 설명이 꼭 필요하면 `/** */` 블록을 쓴다.
- 규칙 적용은 몇 번을 다시 실행해도 결과가 같아야 한다. 렌더 함수는 이전에 붙인 표식 속성을 먼저 지우고 다시 붙인다.
- 사이트 전용 예외 처리를 일반 선택자 코드에 섞지 않는다.

## Flutter 앱 코드 규칙

- 사용자에게 보이는 새 문자열은 `lib/l10n/app_en.arb`와 `app_ko.arb`에 같은 키로 넣고 생성된 `AppLocalizations`로 쓴다. 두 ARB 파일의 키 수는 같아야 한다.
- `dart:io`의 `Process`로 외부 명령을 실행하지 않는다.
- `flutter_inappwebview`의 `ContentBlockerActionType`은 선택자에 `CSS_DISPLAY_NONE`, 네트워크 필터에 `BLOCK`만 쓴다. 다른 동작을 추가하면 커밋 본문에 이유를 적는다.
- 사이트 전용 처리는 이름 붙은 어댑터로 분리한다. 공용 경로에 호스트 이름 분기를 넣지 않는다.
- `dart_code_linter` 기준(순환 복잡도 18, 유지보수 지수 45, 중첩 5, 매개변수 5, 함수 120줄)을 넘기지 않는다. 테스트와 생성물은 제외된다.
- `assets/js/*.js`를 고치면 `dart run tool/generate_user_scripts.dart`로 `.g.dart`를 다시 만들어 같은 커밋에 넣는다. `.g.dart`를 손으로 고치지 않는다.
- 테마 파일에서 `Color(0x...)`를 새로 만들지 않는다. 토큰을 `design/design-tokens.json`에 추가하고 `dart run tool/generate_theme_tokens.dart`로 다시 만든다.

## 환경 설정

- Chrome 확장 빌드는 환경 변수를 읽지 않는다. 템플릿 서버만 `INFOCUTTER_TEMPLATE_HOST`, `INFOCUTTER_TEMPLATE_PORT`, `INFOCUTTER_TEMPLATE_DIR`, `INFOCUTTER_TEMPLATE_CORS_ORIGIN`, `INFOCUTTER_TEMPLATE_TOKEN`을 읽는다.
- Flutter 앱은 컴파일 시 `--dart-define`으로 자동화 브리지 값(`INFOCUTTER_AUTOMATION_TOKEN` 등)을 받는다. 비밀 값을 `--dart-define` 기본값으로 코드에 적지 않는다.
