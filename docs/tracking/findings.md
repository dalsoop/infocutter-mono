# 미해결 문제

## `npm ci`가 커밋된 lock 파일로 실패한다

- 증상: 깨끗한 checkout의 `extensions/chrome`에서 `npm ci`를 돌리면 `Missing: @vibecode/ext-build@0.1.0 from lock file`로 끝난다. 2026-09-30 재현.
- 원인: `package-lock.json`이 `file:../packages/ext-build`(예전 저장소 배치)를 가리키고, `package.json`은 `file:../../packages/ext-build`를 가리킨다.
- 영향: 재현 가능한 설치가 안 된다. CI를 루트로 옮기면 첫 단계에서 멈춘다.
- 지금 못 고치는 이유: 막는 결정은 없다. `npm install`이 만든 lock 변경(경로 세 곳)을 기능 변경과 섞지 않는 단독 커밋으로 넣으면 끝난다.
- 방향: `npm install`로 갱신된 lock 파일(경로 세 곳만 바뀐다)을 단독 커밋한다.

## content script 재주입 목록에 선택자 규칙 패키지가 없다

- 증상: manifest 선언 content script가 붙지 않은 탭(확장 설치·갱신 전에 열린 탭 등)에서 service worker가 `executeScript`로 스크립트를 넣으면, `constants.js`가 `InfocutterSelectorRules`를 찾지 못해 `ReferenceError`가 나고 뒤따르는 스크립트가 멈출 것으로 보인다. 코드 대조로 찾았고 브라우저에서는 재현하지 않았다.
- 원인: `src/background/service-worker.ts`의 `contentScriptFiles`에 `src/content/selector-rules-package.js`가 빠져 있다. `scripts/build.mjs`의 목록에는 있다.
- 영향: 그 탭에서 선택 모드, 우클릭 숨기기, 단축키가 동작하지 않는다.
- 지금 못 고치는 이유: 결정할 것은 없는 코드 수정이지만, 증상이 코드 대조로만 추정되어 있다. 설치 전에 열린 탭에서 실제로 실패하는지 Chrome에서 먼저 재현해야 수정 전후를 비교할 수 있다.
- 방향: 목록 맨 앞에 추가하고, 가능하면 두 목록을 한 곳에서 만들게 한다.

## 같은 코드의 사본이 다른 저장소에 살아 있다

- 증상: `flutter-app-mono`의 `apps/infocutter-app`에는 2026-09-29 커밋이 있고, `chrome-extension-mono`에도 `vibecode-chrome-extension-infocutter`와 `packages/ext-build`가 남아 있다. 이 저장소의 `apps/browser/.codex/AGENTS.md`는 정본이 `flutter-app-mono` 쪽이라고 적고, `apps/browser/README.md`와 `pubspec.yaml` 설명은 옛 경로(`apps/infocutter-app`, `chrome-extension-mono/infocutter`)를 가리킨다. `packages/ext-build/README.md`의 설치 예시 경로도 이 저장소 배치와 다르다.
- 영향: 어느 쪽에 고친 내용이 반영되는지 불분명하고, 두 사본이 갈라진다.
- 지금 못 고치는 이유: 어느 저장소를 정본으로 둘지 소유자가 정해야 한다.
- 방향: 정본을 정한 뒤 나머지 사본을 보관 처리하고 경로 안내를 한 번에 고친다.

## Chrome과 Flutter의 선택자 규칙 적용 결과가 다르다

- 증상: 같은 규칙 JSON이라도 다음 조건에서 두 플랫폼이 다르게 숨긴다.
  - URL에 맞는 프로필이 둘 이상이면 Chrome은 첫 프로필만, Flutter ContentBlocker는 모든 프로필의 `hide` 규칙을 적용한다.
  - `unhide` 대상 요소를 품은 부모를 `hide`가 가리키면 Chrome은 숨기지 않고 Flutter는 숨긴다.
  - `frameScope`가 있는 iframe 규칙은 Flutter ContentBlocker에 들어가지 않는다.
  - AI 결과를 Chrome은 확인 없이 바로 적용하고 Flutter는 사용자 승인 뒤에 적용한다.
- 영향: 제품이 약속하는 "PC와 모바일에서 같은 차단 경험"이 깨진다.
- 지금 못 고치는 이유: 어느 쪽 의미가 맞는지 소유자가 정해야 하고, 그다음 한쪽 코드를 바꿔야 한다.

## 템플릿 서버가 시작되지 않고, 규칙 모드를 잃는다

- 증상 1: `./infocutter templates`, `npm run pipe:templates`, `Dockerfile.templates`가 `ERR_MODULE_NOT_FOUND: scripts/lib.mjs`로 끝난다. 2026-09-30 재현.
- 증상 2: Chrome에서 `unhide` 규칙이 있는 프로필을 템플릿으로 올린 뒤 다시 적용하면 그 규칙이 `hide`로 돌아온다. 서버 `normalizeRule`이 `frameScope`와 `selector`만 남긴다(코드 대조, 서버가 시작되지 않아 실행 확인은 못 했다).
- 영향: Chrome의 유일한 규칙 교환 경로가 막혀 있고, 복구하더라도 예외 규칙이 숨김 규칙으로 바뀐다.
- 지금 못 고치는 이유: 증상 1은 결정할 것 없는 import 수정이다. 증상 2는 서버 템플릿 형식(`version: 1`)에 `mode`를 넣을지, 버전을 올릴지 소유자가 정해야 한다. 서버를 외부에 둘지에 대한 결정(아래 항목)과도 묶여 있다.
- 방향: `@vibecode/ext-build/lib`에서 `logStep`, `projectRoot`를 가져오고, 서버 정규화에 `mode`를 추가한다.

## 템플릿 id가 플랫폼마다 다르다

- 증상: 같은 slug의 템플릿이 Chrome에서는 카드 id `tpl:<slug>:<id>`, Flutter에서는 프로필 id `template-<slug>`와 카드 id `template-<slug>-<id>`가 된다. Chrome 템플릿 프로필이 든 JSON을 Flutter에 가져온 뒤 같은 내장 템플릿을 적용하면 같은 내용의 프로필이 둘 생길 것으로 보인다(코드 대조).
- 지금 못 고치는 이유: 어느 id 규칙을 남길지 정해야 하고, 기존 사용자 데이터의 id를 옮기는 코드가 필요하다.

## Flutter는 규칙 JSON의 버전을 보지 않는다

- 증상: version 1·2 형식(`sites` 맵)을 Flutter에 가져오면 규칙이 0개로 들어온다. 규칙에 해당 카드가 없을 때 카드를 만들어 주는 보정도 Chrome과 다르다.
- 지금 못 고치는 이유: Flutter가 옛 형식을 받아야 하는지가 정해지지 않았다. version 1·2는 Chrome 확장의 초기 저장 형식이라, 이 형식을 가진 사용자가 Flutter로 옮겨 올 경로가 실제로 있는지 소유자가 확인해야 한다.

## 알 수 없는 저장소 버전을 만나면 사용자 데이터가 사라질 수 있다

- 증상: 규칙 저장소가 version 1~4 밖이거나 감시 저장소가 version 1이 아니면 빈 저장소로 읽히고, 다음 저장 때 빈 값이 기록된다(코드 대조).
- 영향: 확장 되돌림 배포나 다른 도구의 쓰기 한 번으로 사용자 규칙 전체가 지워진다.
- 지금 못 고치는 이유: 알 수 없는 버전을 만났을 때의 처리(읽기 전용 모드, 백업 보관 등)를 정하고 코드를 바꿔야 한다.

## 이 저장소에서 CI가 돌지 않는다

- 증상: 저장소 루트에 `.github/workflows`가 없다. `apps/browser/.github/workflows/main.yml`(태그 푸시 시 릴리스 빌드, `ref: master` checkout)과 `extensions/chrome/.gitlab-ci.yml`은 하위 디렉터리에 있어 GitHub가 읽지 않는다.
- 영향: PR에 자동 검사가 없고, 게이트는 사람이 로컬에서 돌려야 한다.
- 지금 못 고치는 이유: CI를 둘지, 어떤 러너에서 돌릴지 소유자가 정해야 한다.

## Chrome pre-commit 도구가 이 배치에서 동작하지 않는다

- 증상: `tools/install-hooks.sh`는 `extensions/chrome/.git/hooks`에 쓰려 하고, 훅은 저장소 루트 기준 `tools/pre-commit.sh`를 부른다. `no-comments-gate.sh`는 shebang 줄을 주석으로 오판해 `extensions/chrome`에서 항상 실패한다. 2026-09-30 재현.
- 지금 못 고치는 이유: 훅을 저장소 루트에 둘지, Flutter 쪽 검사까지 포함할지, 주석 금지 정책을 Flutter에도 적용할지(Flutter 코드는 주석을 쓴다) 소유자가 정해야 한다.

## Flutter 포맷 검사가 실패하고 SDK 버전이 고정되어 있지 않다

- 증상: Flutter 3.44.0(Dart 3.12.0)에서 `dart format --set-exit-if-changed lib test`가 6개 파일로 실패한다. 앱에 `.fvmrc`가 없어 `fvm flutter`는 전역 버전이 없는 기기에서 동작하지 않는다.
- 지금 못 고치는 이유: 포맷 정리 커밋과, 고정할 Flutter 버전을 정하는 결정이 필요하다.

## 공개 저장소의 라이선스 표기가 맞지 않는다

- 증상: 루트 `README.md`는 MIT 라이선스와 루트 `LICENSE` 파일을 가리키지만 루트에 `LICENSE`가 없다. `apps/browser/LICENSE`는 fork 원본에서 온 Apache-2.0이다.
- 영향: 공개 저장소의 사용 조건이 불분명하다.
- 지금 못 고치는 이유: 소유자의 라이선스 결정이 필요하다.

## 루트 README의 제품 설명이 코드와 다르다

- 증상: 루트 `README.md`는 증거 PDF를 "법적/업무적 효력을 갖춘" 문서로, 저장 HTML을 "전체 DOM HTML"로 설명한다. Chrome 코드는 매칭 블록의 `outerHTML`만 저장하고, PDF에는 "소명 참고자료이며 추가 절차가 필요할 수 있다"는 고지를 넣는다. 선택자 숨김도 `<style>`에 선택자를 넣는 방식이 아니라 요소에 속성을 붙이는 방식이다.
- 영향: 사용자가 증거의 효력을 과신할 수 있다.
- 지금 못 고치는 이유: 제품 문구를 어떻게 바꿀지 소유자가 정해야 한다.

## `packages/ext-runtime`에 이 저장소 안 소비자가 없다

- 증상: 이 저장소의 어떤 코드도 `ext-runtime`을 import하지 않는다. `sync-consumers.mjs`는 이 저장소에 없는 `vibecode-chrome-extension-seo-check`, `vibecode-chrome-extension-youtube-evaluator`에 복사하려 한다.
- 지금 못 고치는 이유: 패키지를 남길지 지울지 소유자가 정해야 한다.

## Chrome content script에 자동 테스트가 없다

- 증상: `src/content/*`(선택 모드, 렌더링, 텍스트 블록 런타임, 감시 칩)는 테스트가 없고 `node --test`는 DOM이 없는 환경에서 돈다.
- 영향: 선택자 적용 순서나 예외 처리가 깨져도 게이트가 초록이다.
- 지금 못 고치는 이유: DOM 테스트 환경(예: jsdom이나 브라우저 자동화)을 들이는 의존성 결정이 필요하다.

## options 화면에 `innerHTML` 대입이 하나 남아 있다

- 증상: `src/options/site-card-dom.ts`의 `createProfileEditFields`가 matcher 힌트 목록을 `innerHTML`로 넣는다. 지금 넘어오는 값은 코드 안 고정 문자열뿐이라 주입 위험은 없지만, 호출자가 사용자 값을 넘기면 바로 주입 경로가 된다. ESLint 규칙은 이 대입을 잡지 못했다.
- 지금 못 고치는 이유: 결정할 것은 없는 작은 코드 수정이다. 다만 ESLint의 `innerHTML` 금지 규칙이 이 대입을 왜 잡지 못했는지 확인해 규칙 설정도 함께 고쳐야 같은 누락이 반복되지 않는다.

## 실기기 IdP 로그인이 확인되지 않았다

- 증상: Google 계정 로그인은 2026-08-04 에뮬레이터·시뮬레이터에서 로그인 페이지 표시까지만 확인했다. 자격 증명 제출 이후 단계와 실기기는 확인하지 않았다.
- 지금 못 고치는 이유: Android·iOS 실기기와 테스트 계정이 필요하다.

## Chrome 선택자 생성 코드가 두 벌이고 서로 다르다

- 증상: `src/shared/selector.ts`의 `buildSelectorCandidates`와 `src/content/selector-engine.ts`의 같은 이름 함수가 따로 있다. 후보가 없을 때의 대체 선택자, 조상 경로 선택자, 직접 후보의 유일성 검사 방식이 다르다. 선택 모드가 쓰는 것은 content 쪽이고, shared 쪽 함수는 런타임에서 부르는 곳이 없으며 테스트도 `selectorCss`만 가져다 쓴다.
- 영향: shared 쪽을 고치고 테스트를 추가해도 실제 선택 모드 동작은 바뀌지 않는다.
- 지금 못 고치는 이유: 어느 구현을 정본으로 남길지 정해야 한다. content 쪽을 정본으로 하려면 선택자 생성 코드를 도메인 패키지로 옮겨 IIFE로 내보내는 빌드 변경이 필요하다.

## 작업 방식 규칙 하나를 유지할지 정해지지 않았다

- 증상: 이전 `extensions/chrome/AGENTS.md`에는 "Keep diffs small. Delete before adding abstractions."가 있었다. 위반 여부를 판정할 기준이 없어 현재 규칙 목록에서는 뺐다.
- 지금 못 고치는 이유: 이 원칙을 판정 가능한 규칙(예: 변경 줄 수 상한, 새 추상화 도입 시 삭제 코드 동반)으로 바꿀지, 버릴지 소유자가 정해야 한다.

## 보안 설정 관련 문제

- 보안 이슈 있음, 비공개 추적.
- 자동화 브리지, 템플릿 서버, AI 키 보관, AI 전송 기본값에 관한 소유자 결정이 남아 있으며, 결정 전까지 디버그 앱과 템플릿 서버는 신뢰하는 기기의 루프백에서만 쓴다.
