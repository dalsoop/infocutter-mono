# 엔지니어링 노트

## Chrome 확장

### `npm ci`가 lock 파일 불일치로 실패한다

- 증상: `extensions/chrome`에서 `npm ci`가 `Missing: @vibecode/ext-build@0.1.0 from lock file`로 끝나고, 이어서 `eslint: command not found`, `Cannot find type definition file for 'chrome'`이 난다.
- 원인: 커밋된 `package-lock.json`이 예전 저장소 배치의 `file:../packages/ext-build`를 가리킨다. 이 저장소에서는 `package.json`이 `file:../../packages/ext-build`를 가리킨다.
- 대응: `npm install`을 쓴다. `npm install`은 lock 파일의 세 군데 경로를 `../../packages/ext-build`로 고친다. 이 lock 변경은 기능 변경과 섞지 말고 따로 커밋한다.
- 확인: `npm run pipe:check`가 끝까지 돌고 `ℹ fail 0`이 나온다.

### content script 목록은 세 군데에 있고, 실제로 쓰이는 것은 두 곳이다

- `public/manifest.json`의 `content_scripts[0].js`: 빌드가 이 값을 덮어쓴다. 여기만 고치면 아무 효과가 없다.
- `scripts/build.mjs`의 `contentScriptFiles`: `dist/manifest.json`에 들어가는 실제 목록이다.
- `src/background/service-worker.ts`의 `contentScriptFiles`: 탭이 응답하지 않을 때 `chrome.scripting.executeScript`로 다시 넣는 목록이다. 지금 이 목록에는 `src/content/selector-rules-package.js`가 빠져 있다.

순서도 동작의 일부다. IIFE 패키지 세 개가 먼저, `constants.js`가 그다음, `index.js`가 마지막이어야 한다. `constants.js`는 첫 줄에서 `InfocutterSelectorRules.infocutterMessageTypes`를 읽으므로 패키지보다 먼저 오면 `ReferenceError`로 뒤따르는 스크립트가 모두 멈춘다.

content script 파일을 추가·삭제·개명할 때의 점검 순서:

1. `scripts/build.mjs`의 `contentScriptFiles`에 올바른 순서로 넣는다.
2. `src/background/service-worker.ts`의 `contentScriptFiles`도 같은 순서로 맞춘다.
3. 다른 content 파일이 쓰는 전역 함수라면 `src/content/contracts.d.ts`에 선언한다.
4. `npm run pipe:build` 뒤 `node -e 'console.log(require("./dist/manifest.json").content_scripts[0].js)'`로 목록을 눈으로 확인한다.
5. 확장을 다시 읽어 들인 뒤 **확장 설치 전에 열려 있던 탭**에서 선택 모드를 켜 본다. 이 경로가 service worker 쪽 목록을 쓴다.

### 도메인 패키지에 새 export를 추가하면 content script에서만 `undefined`가 된다

- 증상: `tsc`와 테스트는 통과하는데 페이지에서 `InfocutterSelectorRules.someNewFn is not a function`이 난다.
- 원인: `scripts/build.mjs`가 패키지의 `dist/index.js`에서 `export` 키워드를 지우고 IIFE로 감싼 뒤, `selectorRulesPackageExports`, `textBlocksPackageExports`, `watchPackageExports` 목록에 있는 이름만 반환한다. 반면 `contracts.d.ts`는 모듈 전체 타입을 선언하므로 타입 검사는 통과한다.
- 대응: content script에서 쓸 새 export는 `build.mjs`의 해당 목록에도 추가한다. background·options·popup은 ES 모듈 import를 쓰므로 목록과 관계없다.

### content 쪽 상수는 두 벌이다

`src/content/constants.ts`는 `src/shared/constants.ts`의 저장소 키, 버전, 속성 이름, AI 수집 한도를 다시 선언한다. content script가 모듈 import를 못 쓰기 때문이다. 한쪽만 바꾸면 content script와 service worker·options가 서로 다른 키나 버전을 읽는다. 두 파일을 함께 고치고 `grep -n "<바꾼 이름>" src/content/constants.ts src/shared/constants.ts`로 두 값이 같은지 확인한다.

### 알 수 없는 저장소 버전은 빈 저장소가 된다

- 증상: 확장을 이전 빌드로 되돌리거나 다른 도구가 `version`을 바꿔 쓴 뒤 규칙이 모두 사라진다.
- 원인: `normalizeRuleStore`는 version 1~4만 읽고 나머지는 빈 저장소를 돌려준다. 감시 저장소는 version 1이 아니면 빈 저장소를 돌려준다. 그 상태에서 사용자가 무엇이든 저장하면 빈 저장소가 실제로 기록된다.
- 대응: 버전을 올리는 변경은 이전 버전 읽기 분기와 테스트를 먼저 넣는다. 확장을 되돌리는 배포는 하지 않는다.

### 콘텐츠 스크립트를 두 번 넣으면 전역 선언이 충돌한다

content script는 최상위 `const`·`let`·`function`으로 전역을 선언한다. 이미 스크립트가 붙은 frame에 같은 파일을 다시 주입하면 `Identifier has already been declared`로 실패한다. 그래서 `ensureTabReady`는 먼저 `ping`을 몇 차례(80~520ms 간격) 다시 보내 manifest 선언 스크립트가 붙을 시간을 준 다음에만 직접 주입한다. 이 대기를 줄이거나 없애면 빠르게 새로 고친 탭에서 오류가 난다.

### 증거 PDF 빌더 함수는 스스로 완결되어야 한다

`src/evidence/page-evidence-builder.ts`의 `buildEvidenceInPage`는 Safari 경로에서 `chrome.scripting.executeScript({ func })`로 페이지에 직렬화되어 들어간다. 함수 본문 밖의 import, 모듈 상수, 클로저를 참조하면 Chrome(offscreen 경로)에서는 동작하지만 Safari 경로에서만 `ReferenceError`가 난다. 헬퍼는 모두 함수 안에 중첩하고, jsPDF는 `globalThis.jspdf`에서만 가져온다. offscreen 문서도 같은 함수를 쓰므로 한 곳만 고치면 된다.

### 테스트는 빌드 결과물을 돌린다

`npm run pipe:test`는 `pipe:build`(정리 → 패키지 컴파일 → 전체 tsc → 번들 복사)를 먼저 하고 `node --test 'dist/tests/*.js'`를 실행한다. 테스트 파일은 `tests/*.test.ts`이고 import 경로는 `.js` 확장자로 쓴다. 테스트 대상은 `src/shared`, `packages/*`, `src/evidence`, options 보조 함수다. `src/content/*`는 DOM 테스트가 없어서 content script 동작은 테스트로 확인되지 않는다. content script를 바꿨으면 브라우저에 확장을 올려 직접 확인한다.

### 프로필 순서가 규칙 적용을 바꾼다

필터 목록에서 도메인 없는 cosmetic 규칙(`##.ad`)을 가져오면 matcher `*://*/*` 프로필이 생긴다. 이 프로필이 사이트 전용 프로필보다 위에 있으면 그 사이트 프로필은 적용되지 않고, 선택 모드로 새로 고른 규칙도 전역 프로필에 저장되어 모든 사이트에 적용된다. 사용자 문의가 "특정 사이트 규칙이 안 먹는다" 또는 "다른 사이트까지 가려진다"면 options 화면의 프로필 순서부터 확인한다.

### 템플릿 서버 스크립트는 지금 실행되지 않는다

`scripts/templates-server.mjs`는 `./lib.mjs`를 import하는데 이 저장소의 `scripts/`에는 `lib.mjs`가 없다. `./infocutter templates`, `npm run pipe:templates`, `Dockerfile.templates`는 모두 `ERR_MODULE_NOT_FOUND`로 끝난다. 다른 스크립트들은 같은 함수(`logStep`, `projectRoot` 등)를 `@vibecode/ext-build/lib`에서 가져온다.

### pre-commit 도구는 이 저장소 배치에서 동작하지 않는다

- `tools/install-hooks.sh`는 `extensions/chrome/.git/hooks`에 훅을 쓰려 하지만 git 디렉터리는 저장소 루트에 있다.
- 훅 본문은 `$(git rev-parse --show-toplevel)/tools/pre-commit.sh`를 부르는데, 그 경로는 저장소 루트 기준이라 존재하지 않는다.
- `tools/scripts/no-comments-gate.sh`는 `grep -n` 결과(`1:#!/usr/bin/env bash`)에 `^\s*#!` 제외를 걸어서 shebang을 걸러 내지 못한다. `extensions/chrome`에서 돌리면 `.sh` 파일 세 개와 `vendor/jspdf.js`(소스맵 주석) 때문에 항상 실패한다.
- 대응: 게이트는 `npm run pipe:check`를 직접 돌린다. 주석 규칙은 `grep -rnE '^\s*//' src packages/*/src tests`가 아무것도 출력하지 않는지로 확인한다.

## Flutter 앱

### `fvm flutter`가 이 앱에서 바로 되지 않을 수 있다

- 증상: `apps/browser`에서 `fvm flutter --version`이 `/bin/sh: flutter: command not found`로 끝난다.
- 원인: 앱에 `.fvmrc`가 없고, fvm 전역 버전도 지정되지 않은 기기에서는 fvm이 PATH의 `flutter`를 찾는다.
- 대응: `fvm global <버전>`으로 전역 버전을 정하거나, fvm 캐시의 SDK(`<fvm 캐시>/versions/<버전>/bin/flutter`)를 직접 부른다. 2026-09-30 검증은 Flutter 3.44.0(stable)으로 했다. `pubspec.yaml`은 `flutter >=3.24.0`, Dart `^3.5.0`만 요구한다.

### `dart format` 결과가 SDK 버전마다 다르다

Dart 3.12.0 포매터로 `dart format --set-exit-if-changed lib test`를 돌리면 `lib/app_bar/webview_tab_address_field.dart`, `lib/browser.dart`, `lib/pages/settings/cross_platform/cross_platform_settings_section1.dart`, `lib/reader/reader_mode.dart`, `lib/webview_tab.dart`, `lib/webview_tab_request_handlers.dart` 여섯 파일이 바뀐다. 이 파일들을 포매팅하는 변경은 기능 변경과 섞지 말고 따로 커밋해야 리뷰할 수 있다.

### 주입 JS는 Dart 문자열로 구워진다

`assets/js/*.js`는 `tool/generate_user_scripts.dart`가 `lib/infocutter/generated/user_scripts.g.dart`의 raw 문자열 상수로 바꾼다. JS 안에 `'''`(작은따옴표 세 개)가 들어가면 Dart raw 문자열이 끊겨 컴파일이 깨진다. JS는 WebView 안에서만 돌기 때문에 JS 문법 오류나 전역 객체 노출 누락은 `flutter analyze`와 `flutter test`가 잡지 못하고 실기기에서만 드러난다. `node tool/js_test.mjs`가 `infocutter_runtime.js`, `picker.js`, `keyword_capture.js`의 파싱과 전역 노출(`__infocutterRuntime` 등), `.g.dart` 동기, 삼중 따옴표를 검사한다. `lazy_image_promote.js`는 이 검사 대상에 없고, Dart 테스트(`test/infocutter/lazy_image_promote_js_test.dart`)가 생성물 동기와 특정 문자열 포함 여부만 본다. 파싱 오류는 잡지 못한다. 셀렉터 점수 같은 알고리즘은 어느 스크립트도 자동 검사로 확인되지 않는다.

JS를 고칠 때의 순서:

1. `assets/js/<파일>.js`를 고친다.
2. `dart run tool/generate_user_scripts.dart`로 `.g.dart`를 다시 만든다.
3. `node tool/js_test.mjs`와 `dart run tool/generate_user_scripts.dart --check`를 돌린다.
4. 디버그 빌드를 기기나 시뮬레이터에서 띄워 해당 기능을 한 번 실행한다.

### ContentBlocker와 JS 런타임이 서로 다른 프로필 집합을 쓴다

선택자 숨김은 ContentBlocker(모든 매칭 프로필의 합집합, 최상위 문서 규칙만)와 JS 런타임(첫 매칭 프로필 하나, iframe 규칙 포함)의 두 경로로 적용된다. 사이드바가 보여 주는 활성 프로필과 실제로 가려지는 요소가 다를 수 있다. 숨김 관련 버그를 볼 때는 어느 경로가 요소를 가렸는지부터 가른다. ContentBlocker는 WebView 설정 교체로만 바뀌므로 설정 적용 후 새로 고침이 필요한 경우가 있다.

### macOS 빌드에서 `flutter_inappwebview_macos` 컴파일이 깨질 때

Xcode 26에서 `WebAuthenticationSession`의 protocol conformance 때문에 macOS 빌드가 실패하면 `tool/patch_macos_inappwebview.sh`를 실행한다. 이 스크립트는 저장소가 아니라 사용자 홈의 `.pub-cache` 안 플러그인 소스를 고치므로, `flutter pub cache repair`나 플러그인 버전 변경 뒤에는 다시 실행해야 한다. 이미 패치된 파일은 표식(`INFOCUTTER_WAS_PATCH_V2`)으로 건너뛴다.

### 디자인 토큰 스냅샷

색 정본은 macOS 앱 `design-system-studio`에 있지만 앱 빌드는 커밋된 `design/design-tokens.json`만 읽는다. studio가 없는 기기에서도 빌드와 `--check`가 돌게 하기 위해서다. 색을 바꾸려면 studio에서 export한 JSON으로 스냅샷을 바꾸고 `dart run tool/generate_theme_tokens.dart`를 돌린다. 테스트가 라이트·다크 색 값을 고정해 두었으므로 브랜드 색을 의도적으로 바꾸면 그 테스트 기대값도 같은 커밋에서 고친다.
