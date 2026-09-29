# 아키텍처

## 전체 구성

인포커터는 서버가 없는 클라이언트 제품이다. 두 개의 독립 런타임이 같은 규칙 모델을 각자 구현하고, 규칙은 JSON으로만 서로 오간다. 두 런타임은 코드를 공유하지 않는다. Flutter 앱은 Chrome 쪽 TypeScript 도메인 로직을 Dart로 다시 작성해 두었다.

```
[Chrome MV3 확장 extensions/chrome]                 [Flutter 브라우저 apps/browser]
 service worker ── chrome.runtime 메시지 ── content scripts     Dart 서비스(lib/infocutter) ── InAppWebView
      │                                     (모든 frame)            │                   ├─ ContentBlocker
      ├─ declarativeNetRequest 동적 규칙                             │                   ├─ UserScript(assets/js)
      ├─ offscreen 문서(증거 PDF 합성)                               │                   └─ shouldInterceptRequest
      ├─ downloads(증거 파일 저장)                                   ├─ SharedPreferences(규칙·설정)
      └─ chrome.storage.local / IndexedDB                           ├─ flutter_secure_storage(AI 키)
                                                                    └─ 앱 지원 디렉터리(증거 파일)
          │                                                                  │
          └──── 규칙 JSON (infocutter.ruleStore, version 4) : 클립보드·템플릿 JSON ────┘

외부: OpenAI 호환 chat/completions 엔드포인트(AI 마스킹, 사용자 키) · 템플릿 서버(선택, 로컬 Node)
```

## 구성 요소

| 구성 요소 | 위치 | 역할 | 의존 방향 |
|---|---|---|---|
| Chrome 확장 | `extensions/chrome` | 데스크톱 Chrome에서 요소 숨김, 텍스트 블록, 감시, 증거, 네트워크 차단, AI 마스킹을 수행한다 | `packages/ext-build`(빌드 시), `extensions/chrome/packages/*`(소스 포함) |
| 확장 도메인 패키지 | `extensions/chrome/packages/infocutter-*` | 선택자 규칙·텍스트 블록·감시 저장소 모델과 필터 목록 파서를 순수 함수로 제공한다 | 의존 없음 |
| MV3 빌드 파이프라인 | `packages/ext-build` | `build`·`doctor`·`dev`·`watch`·`package` 단계를 매개변수로 제공한다 | Node 표준 라이브러리만 사용 |
| MV3 런타임 스캐폴드 | `packages/ext-runtime` | i18n·설정 저장소·메시지 봉투 코드의 원본이다. 이 저장소 안에는 소비자가 없다 | 없음 |
| Flutter 브라우저 | `apps/browser` | `flutter_browser_app` fork 위에 인포커터 기능(`lib/infocutter/`)을 얹은 Android·iOS·macOS·Windows 앱이다 | pub 패키지, `flutter_inappwebview`(git 커밋 고정) |
| 자동화 MCP 서버 | `apps/browser/mcp` | 디버그 빌드 앱의 자동화 브리지를 MCP 도구로 노출한다 | 앱의 `127.0.0.1:47821` HTTP 브리지 |
| 소개 페이지·블로그 | `extensions/chrome/introduce` | 정적 HTML 랜딩과 블로그 글이다. 확장 빌드에 포함되지 않는다 | 없음 |

## Chrome 확장 내부

`src/`는 네 레이어로 나뉜다. `src/background`(service worker)는 탭 준비, 배지, 컨텍스트 메뉴, 단축키, 네트워크 규칙 적용, 증거 캡처 조율, AI 분석 호출을 맡는다. `src/content`는 페이지 안에서 규칙 렌더링, 선택 모드(picker), 텍스트 블록, 감시 칩, AI 후보 수집을 한다. `src/popup`과 `src/options`는 사용자 조작 화면이다. `src/shared`는 저장소 읽기·쓰기, 타입, 메시지 이름, AI 클라이언트를 둔다. `src/offscreen`과 `src/evidence`는 증거 PDF 합성을 맡는다.

content script는 ES 모듈이 아니다. 빌드가 도메인 패키지 IIFE 3개(`selector-rules-package.js`, `text-blocks-package.js`, `watch-package.js`)와 `src/content`에서 컴파일된 스크립트 22개, 모두 25개를 manifest의 `content_scripts[0].js`에 순서대로 등록하고, 이 파일들은 같은 전역 스코프를 공유한다. 따라서 content 쪽 코드는 `import` 대신 `globalThis.InfocutterSelectorRules` 같은 전역과 `src/content/constants.ts`에 다시 선언한 상수를 쓴다.

## 대표 흐름

### Chrome: 요소를 골라 숨기기

1. 사용자가 팝업 버튼, `Alt+Shift+P`, 컨텍스트 메뉴 중 하나로 선택 모드를 시작한다.
2. service worker가 `ensureTabReady`로 content script 응답(`infocutter/ping`)을 여러 번 확인하고, 끝내 응답이 없으면 `chrome.scripting.executeScript`로 모든 frame에 스크립트를 주입한다. 준비되면 모든 frame에 `stop-picker`, 최상위 frame에 `start-picker`를 보낸다.
3. content script의 picker가 요소 위 오버레이를 그리고 선택자 후보를 만든다. 사용자가 확정하면 현재 URL에 매칭되는 첫 프로필(없으면 `origin/*` matcher로 새 프로필)에 규칙을 추가해 `chrome.storage.local`에 쓴다. iframe 안에서 고른 규칙은 `frameScope`에 그 frame의 `origin + pathname`이 기록된다.
4. 모든 탭의 content script가 `chrome.storage.onChanged`를 받아 `renderAllRules`(선택자 → 텍스트 블록 → AI 순서)를 다시 실행한다. 선택자 규칙은 대상 요소에 `data-infocutter-selector-hidden` 속성을 붙이고, 그 속성에 `display: none !important`를 거는 스타일 하나로 숨긴다.
5. `MutationObserver`가 DOM 변경을 감지하면 120ms 뒤 다시 렌더링한다.

### Chrome: 감시 대상 증거 저장

1. content script가 감시 대상 이름·별칭이 들어간 블록을 찾으면 흐림 처리(`autoMask`가 켜진 경우)하고 칩을 띄운다.
2. 사용자가 칩에서 저장을 누르면 content script가 대상 요소의 `outerHTML`(최대 200,000자), URL, 제목, 매칭어를 `infocutter/capture-evidence`로 보낸다.
3. service worker가 `captureVisibleTab`으로 페이지 전체를 타일로 캡처하고, `chrome.offscreen`이 있으면 offscreen 문서에서, 없으면(iOS Safari) 페이지에 `vendor/jspdf.js`와 빌더 함수를 주입해 PNG·PDF·SHA-256을 만든다.
4. 같은 URL과 같은 HTML 해시의 기록이 IndexedDB `infocutter-evidence`에 있으면 저장하지 않는다. 없으면 `Downloads/infocutter-evidence/<매칭어>/<시각>.{pdf,png,html,manifest.json}` 네 파일을 내려받고 기록을 추가한다.

### Flutter: 페이지 로드 시 규칙 적용

1. 탭 URL이 바뀌면 `InfocutterRuntimeApplier`가 WebView 설정을 다시 만든다. 인증 origin이거나 사용자가 해당 호스트를 보호 해제(`SiteProtectionBypass`)했으면 ContentBlocker 목록을 비우고 주입을 건너뛴다.
2. 그 밖의 경우 선택자 규칙은 URL에 매칭되는 모든 활성 프로필에서 ContentBlocker(`CSS_DISPLAY_NONE`, 최상위 문서 규칙만)로 만든다. 네트워크 필터는 `BLOCK` ContentBlocker, 탐색 취소(`shouldOverrideUrlLoading`), 하위 리소스 차단(`shouldInterceptRequest`) 세 경로로 적용한다.
3. WebView를 만들 때 `initialUserScripts`로 picker, 런타임, 키워드 캡처, 지연 이미지 승격 스크립트를 넣는다. 이 스크립트의 원본은 `assets/js/*.js`이고 Dart 상수 파일은 생성물이다. URL이 바뀔 때마다 선택자·텍스트 블록·감시 runtime contributor 세 개가 현재 URL의 규칙 상태를 페이지에 주입한다.
4. 페이지 쪽 결과는 `infocutter.pickerResult`, `infocutter.keywordResult` 같은 JavaScriptHandler로 Dart에 돌아온다.

## 외부 의존

| 대상 | 쓰는 곳 | 건너가는 것 |
|---|---|---|
| OpenAI 호환 `chat/completions` | Chrome `src/shared/ai-llm-client.ts`, Flutter `ai_masking_service.dart` | 사용자가 입력한 API 키(Bearer)와 페이지 블록 정보. 기본 엔드포인트는 Chrome `https://llm.ranode.net/v1`, Flutter `https://api.openai.com/v1/chat/completions`로 서로 다르다 |
| 템플릿 서버 | Chrome options, `scripts/templates-server.mjs` | 템플릿 JSON 목록·조회·저장·삭제. 기본 주소 `http://127.0.0.1:41800` |
| `flutter_inappwebview` | Flutter 전체 | git 저장소의 특정 커밋으로 고정되어 있다 |
| `vendor/jspdf.js` | Chrome 증거 PDF | 저장소에 포함된 사본을 `dist/vendor`로 복사해 쓴다 |
| Xcode `safari-web-extension-converter` | `npm run pipe:safari` | `dist/`를 iOS Safari 확장 Xcode 프로젝트(`safari-ios/`)로 변환한다 |
| Infisical | `apps/browser/tools/materialize-signing.sh` | Android 릴리스 서명 키 네 값을 읽어 `android/key.properties`와 keystore를 만든다 |

## 경계를 넘는 것과 넘지 않는 것

- Chrome과 Flutter 사이에는 규칙 JSON만 오간다. 텍스트 블록, 감시, 네트워크 필터, AI 규칙, 증거 기록은 플랫폼 사이에서 옮기는 경로가 없다.
- Flutter 앱은 Chrome 확장의 JS 파일을 불러 쓰지 않는다. WebView에 주입하는 JS는 `apps/browser/assets/js/`에 따로 있다.
- 사용자 데이터는 기기 밖으로 나가지 않는다. 예외는 사용자가 AI 키를 설정하고 AI 분석을 실행했을 때의 LLM 요청, 그리고 사용자가 템플릿 서버를 설정해 템플릿을 올릴 때뿐이다.
