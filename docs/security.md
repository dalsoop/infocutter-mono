# 보안

## 보호 대상

| 자산 | 민감한 이유 | 위치 |
|---|---|---|
| 감시 대상 이름·별칭 | 사용자가 피하고 싶은 사람이 누구인지 드러난다 | Chrome `chrome.storage.local`의 `infocutter.watchStore`, Flutter SharedPreferences |
| 증거 파일과 기록 | 사용자가 겪은 피해 내용과 방문 기록이 담긴다 | Chrome 다운로드 폴더와 IndexedDB, Flutter 앱 지원 디렉터리 |
| 규칙·텍스트 블록 키워드 | 사용자가 보기 싫어하는 이름과 사이트가 드러난다 | 각 플랫폼 로컬 저장소 |
| AI API 키 | 사용자 과금 계정에 접근한다 | Chrome `infocutter.aiConfig`, Flutter 보안 저장소 |
| 템플릿 서버 토큰 | 템플릿을 쓰고 지울 수 있다 | Chrome `infocutter.templateServerToken`, 서버 환경 변수 `INFOCUTTER_TEMPLATE_TOKEN` |
| 자동화 브리지 토큰 | 로그인된 페이지에서 임의 JS 실행을 허용한다 | 앱 실행 인자 `--dart-define=INFOCUTTER_AUTOMATION_TOKEN`, MCP 서버 환경 변수 |
| Android 릴리스 서명 키 | 스토어 앱 업데이트 권한과 같다 | Infisical에 보관하고, 빌드 전에 `apps/browser/tools/materialize-signing.sh`가 `android/key.properties`와 `.jks`로 풀어 놓는다. 두 파일은 gitignore 대상이다 |

저장소는 GitHub에 공개되어 있다. 위 값 가운데 어느 것도 코드, 템플릿 JSON, 테스트 픽스처, 문서에 넣지 않는다.

## 계정과 인증

제품에는 계정, 로그인, 서버 쪽 사용자 데이터가 없다. 모든 사용자 데이터는 기기 안에 있고, 확장을 지우거나 앱 데이터를 지우면 함께 사라진다(Chrome 다운로드 폴더와 Flutter 증거 파일은 파일로 남는다). 따라서 권한 모델은 "기기 사용자 한 명이 모든 데이터에 접근한다" 하나뿐이고, 사용자 사이의 접근 제어는 없다.

## 인증 origin 배제 (Flutter 앱)

임베디드 WebView 안의 IdP 로그인은 IdP 정책상 차단 대상이고, 그 정책이 막으려는 것은 인증 페이지에 스크립트를 넣고 요청을 가로채는 앱이다. 앱은 다음 origin에서 인포커터 기능을 전부 끈다.

- 호스트 전체와 그 서브도메인: `accounts.google.com`, `login.microsoftonline.com`, `appleid.apple.com`
- 경로 한정: `github.com`의 `/login` 이하, `gitlab.com`의 `/users/sign_in` 이하

판정 규칙은 다음과 같다.

- `http`, `https`만 대상이다. `about:`, `data:`, `file:`은 인증 origin이 아니다.
- 호스트는 대소문자를 무시하고 끝의 점(`accounts.google.com.`)을 떼어 비교한다. port는 보지 않는다.
- 서브도메인은 점 경계로만 인정한다. `x.accounts.google.com`은 인증 origin이고, `evilaccounts.google.com`과 `accounts.google.com.evil.com`은 아니다.
- 경로는 세그먼트 경계까지 본다. `/login`, `/login/`, `/login/oauth`는 인증이고 `/loginfoo`는 아니다.

인증 origin이면 다음이 모두 꺼진다. 하나라도 빠지면 절대 규칙 위반이다.

| 지점 | 동작 |
|---|---|
| WebView 설정 | ContentBlocker 목록을 빈 목록으로 덮어 이전 페이지의 차단 규칙이 남지 않게 한다 |
| `shouldOverrideUrlLoading` | 인증 origin으로 가는 탐색은 네트워크 필터로 취소하지 않는다 |
| `shouldInterceptRequest` | 요청 URL이나 **현재 페이지 URL** 중 하나라도 인증 origin이면 가로채지 않는다 |
| runtime contributor | 선택자·텍스트 블록·감시 스크립트 주입을 건너뛴다 |
| 화면 | 로그인이 보장되지 않는다는 안내 배너를 띄운다 |

앱은 User-Agent를 위장하지 않는다. Android WebView는 `Sec-CH-UA`에 WebView임을 스스로 붙이고, `X-Requested-With`를 끄는 origin allow-list 기능은 현재 WebView에서 지원되지 않는다(2026-08-04 에뮬레이터·시뮬레이터 측정). 실기기에서 자격 증명 제출 이후 단계는 확인되지 않았다.

Chrome 확장에는 이 배제 목록이 없다. content script는 manifest상 모든 `http`·`https` 페이지와 모든 frame에서 돈다. 로그인은 브라우저가 직접 처리하므로 임베디드 WebView 정책 문제는 생기지 않지만, 사용자가 인증 페이지에 맞는 프로필을 만들면 그 페이지에서도 요소가 숨겨진다.

## Chrome 권한

`permissions`는 `storage`, `tabs`, `contextMenus`, `scripting`, `webNavigation`, `declarativeNetRequest`, `offscreen`, `unlimitedStorage`, `downloads`이고 `host_permissions`는 `<all_urls>`다. 요구 버전은 Chrome 120 이상이다.

- 권한을 새로 추가하면 스토어 심사와 설치 경고가 달라진다. 새 권한은 그 권한을 쓰는 코드와 같은 변경에 넣고 커밋 본문에 이유를 적는다.
- `npm run pipe:doctor`는 `storage`, `tabs`, `contextMenus`, `scripting`, `declarativeNetRequest`가 manifest에 있는지 검사한다. 이 다섯 개는 빼면 진단이 실패한다.
- declarativeNetRequest 동적 규칙은 id 1,000,000~1,199,999만 인포커터가 관리한다. 이 범위 밖의 규칙을 지우거나 덮어쓰지 않는다.

## 페이지에 코드를 넣는 방식

- Chrome 확장은 원격 코드를 불러오지 않는다. `eval`, `new Function`, 원격 스크립트 삽입을 쓰지 않는다. `innerHTML` 대입은 ESLint가 막는다. 예외 하나(`src/options/site-card-dom.ts`의 고정 문자열 힌트 목록)가 남아 있다.
- jsPDF는 저장소의 `vendor/jspdf.js` 사본만 쓴다.
- Flutter 앱이 WebView에서 실행하는 JS에 사용자 값(선택자, 키워드 등)을 넣을 때는 `jsonEncode`로 JS 리터럴을 만들거나 JavaScriptHandler 인자로 넘긴다. 따옴표로 감싼 문자열 보간은 쓰지 않는다. 선택자에 따옴표가 들어가면 스크립트 주입이 된다.

## 외부로 나가는 데이터

AI 분석을 실행할 때만 페이지 정보가 기기 밖으로 나간다. 사용자가 키를 넣고 분석 버튼을 눌러야 한다.

| 플랫폼 | 보내는 것 | 받는 곳 |
|---|---|---|
| Chrome | 블록 최대 120개마다 CSS 선택자, 텍스트 앞 200자, 이미지 `alt`, 이미지 `src` | 사용자가 정한 엔드포인트. 비워 두면 `https://llm.ranode.net/v1`(운영자 쪽 LiteLLM 서버) |
| Flutter | 요소 최대 80개마다 선택자, 태그, id, class(160자까지), role, 텍스트 **길이**, 크기. 텍스트 본문은 보내지 않는다 | 사용자가 정한 엔드포인트. 기본값 `https://api.openai.com/v1/chat/completions` |

두 플랫폼 모두 API 키를 `Authorization: Bearer` 헤더로 보낸다.

## 자격 증명 보관

- **Chrome AI 키**: `chrome.storage.local`에 평문으로 있다. 같은 프로필의 다른 확장은 읽을 수 없지만, 기기 사용자 권한이 있으면 읽힌다.
- **Flutter AI 키**: `flutter_secure_storage`의 `infocutter.aiConfig.apiKey`에 둔다. 예전 버전이 SharedPreferences에 평문으로 남긴 키는 앱 시작 시 보안 저장소로 옮기고 평문 설정을 다시 저장한다. 사용자가 키를 비우고 저장하면 보안 저장소에서 지운다.
- **템플릿 서버**: `INFOCUTTER_TEMPLATE_TOKEN`이 비어 있으면 `/health` 외 모든 경로(목록, 조회, 생성, 수정, 삭제)가 인증 없이 열린다. CORS 허용 origin 기본값은 `*`다. 기본 bind 주소는 `127.0.0.1`이지만 `compose.templates.yml`과 `./infocutter templates-public`은 `0.0.0.0`으로 연다. 외부에 여는 경우 토큰을 반드시 설정한다.
- **Android 서명**: `materialize-signing.sh`가 `umask 077`로 파일을 만든다. 만든 파일을 커밋하지 않는다.

## 자동화 브리지 (Flutter 디버그 빌드)

- `kDebugMode`에서만 시작한다. release·profile 빌드에서는 열리지 않는다.
- `127.0.0.1:47821`에만 bind한다. 실기기에서는 `adb reverse`나 `iproxy`로 포트를 넘겨야 한다.
- 루프백이라도 같은 기기의 다른 프로세스와 브라우저 페이지가 접근할 수 있다. 그래서 동작을 두 등급으로 나눈다.
  - 일반 등급(상태 읽기, 탭 열기, 클릭 등): 토큰이 설정되지 않았으면 인증 없이 허용한다. 토큰이 설정되어 있으면 토큰이 맞아야 한다.
  - 위험 등급(`page.evalJs`, `ai.config`, `page.screenshot`, `evidence.capture`, `cookie.list`, `cookie.get`, `cookie.set`, `cookie.delete`, `browser.clearData`): 토큰이 설정되지 않은 앱에서는 항상 거부(403)한다.
- 토큰은 `Authorization: Bearer <token>` 또는 `x-infocutter-automation-token` 헤더로 받는다.
- 새 동작이 임의 코드 실행, 로그인 페이지 내용 유출, 비밀 덮어쓰기 중 하나에 해당하면 위험 등급 목록에 넣는다.

## 기록

별도의 감사 로그는 없다. 제품이 남기는 기록은 사용자가 요청한 증거 한 건마다의 manifest(시각, URL, 제목, 매칭어, HTML·PNG SHA-256)뿐이다. 증거 파일을 만든 뒤 manifest를 다시 쓰거나 해시를 다시 계산하는 코드를 넣지 않는다.
