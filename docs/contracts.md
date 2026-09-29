# 외부 계약

인포커터에는 공개 서버 API가 없다. 바깥에서 쓰는 계약은 사용자가 주고받는 JSON 파일 형식, 선택 사항인 템플릿 서버 HTTP API, 디버그 빌드 전용 자동화 브리지, 그리고 확장의 단축키·메뉴다.

## 공통 규칙

- JSON 문자열의 시각은 모두 ISO-8601 UTC 문자열이다. 읽을 수 없는 시각은 `1970-01-01T00:00:00.000Z`로 채운다.
- 입력 JSON의 알 수 없는 필드는 버리고, 형식이 틀린 항목(필수 문자열이 아닌 선택자 등)은 오류 없이 그 항목만 빠진다. 가져오기 전체가 실패하는 경우는 JSON 문법 오류뿐이다.
- 확장 안의 메시지와 두 HTTP 서비스는 모두 `{ "ok": true, ... }` 또는 `{ "ok": false, "error": "<사람이 읽는 메시지>" }` 모양으로 응답한다.

## 선택자 규칙 저장소 JSON

Flutter 앱의 규칙 관리 화면에서 내보내기(클립보드 복사)와 가져오기(붙여 넣기)로 주고받는다. Chrome `chrome.storage.local`의 `infocutter.ruleStore` 값과 같은 모양이다.

```json
{
  "version": 4,
  "settings": { "globalEnabled": true },
  "profiles": [
    {
      "id": "string",
      "name": "string",
      "enabled": true,
      "matchers": ["https://www.example.com/*"],
      "cards": [
        { "id": "string", "name": "string", "enabled": true, "createdAt": "ISO", "updatedAt": "ISO" }
      ],
      "rules": [
        { "cardId": "string", "cardName": "string", "selector": "CSS 선택자", "mode": "hide | unhide", "frameScope": null, "createdAt": "ISO" }
      ],
      "sourceTemplateSlug": null,
      "updatedAt": "ISO"
    }
  ]
}
```

| 필드 | 필수 | 빠졌을 때 |
|---|---|---|
| `profiles[].rules[].selector` | 예 | 그 규칙을 버린다 |
| `profiles[].id` | 아니오 | 새 id를 만든다 |
| `profiles[].name` | 아니오 | 첫 matcher에서 scheme과 끝의 `/*`를 뗀 문자열, matcher도 없으면 `이름 없는 프로필` |
| `profiles[].enabled`, `cards[].enabled` | 아니오 | `true` |
| `rules[].mode` | 아니오 | `unhide`가 아니면 모두 `hide` |
| `rules[].frameScope` | 아니오 | `null`(최상위 문서) |
| `settings.globalEnabled` | 아니오 | `true` |

Flutter 가져오기 결과: 같은 `id`의 프로필은 가져온 내용으로 바뀌고, 나머지 기존 프로필은 남으며, `globalEnabled`는 가져온 값이 된다. Flutter는 `version`을 검사하지 않으며 version 1·2의 `sites` 형식을 읽지 않는다.

## 템플릿 JSON

템플릿 서버와 `extensions/chrome/templates/*.json`이 쓰는 형식이다.

```json
{
  "version": 1,
  "slug": "naver-home-ads-basic",
  "name": "표시 이름",
  "description": "설명",
  "matchers": ["https://www.naver.com/*"],
  "cards": [
    { "id": "card-id", "name": "카드 이름", "enabled": true, "note": "메모",
      "rules": [ { "frameScope": null, "mode": "hide", "selector": "#ad_timeboard" } ] }
  ]
}
```

- `slug`와 `name`이 문자열이 아니면 유효하지 않은 템플릿이다.
- 카드는 `id`와 `name`이 문자열이어야 하고, 규칙은 `selector`가 문자열이어야 한다. 그렇지 않은 카드·규칙은 버린다.
- 서버는 slug를 소문자로 바꾸고 `[a-z0-9._-]` 밖의 문자를 `-`로 바꿔 파일 이름으로 쓴다.
- 서버는 규칙의 `mode`를 저장하지 않는다. Chrome이 `unhide` 규칙을 올려도 서버에 저장된 템플릿을 다시 적용하면 `hide`가 된다.

## 템플릿 서버 HTTP API

기본 주소는 `http://127.0.0.1:41800`이다. `INFOCUTTER_TEMPLATE_TOKEN`이 설정되어 있으면 `/health`를 뺀 모든 요청에 `Authorization: Bearer <토큰>` 또는 `x-infocutter-token: <토큰>` 헤더가 필요하다.

| 요청 | 입력 | 성공 응답 | 오류 |
|---|---|---|---|
| `GET /health` | 없음 | 200 `{ ok, authEnabled, host, port, templatesDir }` | 없음 |
| `GET /templates` | 없음 | 200 `{ ok, templates: [{ slug, name, description, matcherCount, cardCount, ruleCount, ... }] }` | 401 토큰 불일치 |
| `GET /templates/<slug>` | 없음 | 200 `{ ok, template }` | 401, 404 없음 |
| `POST /templates` | 템플릿 JSON | 201 `{ ok, template }` (정규화된 결과) | 401, 500 형식 오류·JSON 문법 오류 |
| `PUT /templates/<slug>` | 템플릿 JSON (본문의 slug는 경로의 slug로 덮인다) | 200 `{ ok, template }` | 401, 500 |
| `DELETE /templates/<slug>` | 없음 | 200 `{ ok, slug }` | 401, 404 없음 |
| `OPTIONS *` | 없음 | 204 | 없음 |
| 그 밖의 경로 | | | 404 |

유효하지 않은 템플릿과 JSON 문법 오류는 400이 아니라 500으로 응답한다.

## 필터 목록 입력

Chrome options의 필터 가져오기는 AdBlock Plus·uBlock Origin 형식 텍스트를 받는다. 줄마다 해석하며, 해석 결과는 선택자 규칙, 선택자 예외, 텍스트 블록 규칙, 네트워크 규칙, 지원 안 함 가운데 하나다. 지원하지 않는 줄은 이유와 함께 건너뛴 개수로 보고되고, 가져오기 전체를 멈추지 않는다. 한 번에 추가되는 네트워크 규칙 번호가 1,199,999를 넘으면 가져오기가 오류로 끝난다.

## 증거 manifest

증거 한 건마다 `manifest.json`이 함께 저장된다. 증거를 제출받는 쪽이 파일 무결성을 확인할 때 쓰는 형식이다.

Chrome:

```json
{
  "capturedAt": "ISO",
  "htmlSha256": "64자 16진수",
  "matchedTerm": "매칭된 감시어",
  "pageTitle": "문서 제목",
  "pngSha256": "64자 16진수",
  "url": "캡처한 페이지 URL"
}
```

- `htmlSha256`은 같은 폴더의 `.html` 파일 바이트(UTF-8)의 SHA-256이고, `pngSha256`은 `.png` 파일 바이트의 SHA-256이다.
- 파일 이름은 `<capturedAt에서 :과 .을 -로 바꾼 값>.{pdf,png,html,manifest.json}`이고, 폴더는 매칭어를 파일 이름에 쓸 수 있게 바꾼 값이다.

Flutter는 같은 폴더에 `page.html`, `page.png`, `summary.pdf`, `manifest.json`을 두고, `htmlSha256`은 `page.html` 전체의 SHA-256이다. 두 플랫폼의 manifest 필드 구성은 완전히 같지 않다.

## 자동화 브리지 HTTP API (Flutter 디버그 빌드)

`http://127.0.0.1:47821`에서만 열린다. 앱에 토큰이 설정되어 있으면 `/health`를 포함한 모든 요청에 `Authorization: Bearer <토큰>` 또는 `x-infocutter-automation-token: <토큰>`이 필요하다.

| 요청 | 입력 | 성공 응답 | 오류 |
|---|---|---|---|
| `GET /health` | 없음 | 200 `{ ok: true, name: "infocutter-automation-bridge", debugOnly: true, authRequired }` | 401 |
| `GET /state` | 없음 | 200 앱 상태 스냅샷(탭, 현재 URL, 인포커터 상태) | 401 |
| `POST /run` | `{ "action": "<동작 이름>", "args": { ... } }` | 200 `{ action, ok: true, ...결과 }` | 400 `action` 누락·본문이 JSON 객체가 아님·동작 실패(`{ action, ok: false, error, code }`), 401, 403 토큰 없는 앱에서 위험 등급 동작 |
| 그 밖의 경로 | | | 404 |

`code`는 `no_current_tab`, `unsupported_action` 같은 기계용 실패 코드다. 위험 등급 동작 목록은 `page.evalJs`, `ai.config`, `page.screenshot`, `evidence.capture`, `cookie.list`, `cookie.get`, `cookie.set`, `cookie.delete`, `browser.clearData`다.

## MCP 서버 (`apps/browser/mcp`)

stdio JSON-RPC로 동작하는 MCP 서버 `infocutter-automation`이다. 도구는 `snapshot`, `new_tab`, `navigate`, `wait_for_load`, `wait_for_selector`, `click`, `fill`, `get_text`, `eval_js`, `screenshot`, `infocutter_pick`, `infocutter_open_panel`, `infocutter_add_block_rule`, `infocutter_list_profiles`, 그리고 브리지 동작 이름을 직접 넘기는 `run`이다. 각 도구는 브리지 `POST /run`으로 바뀌어 전달되므로 오류 조건은 브리지와 같다. `INFOCUTTER_BRIDGE_URL`과 `INFOCUTTER_AUTOMATION_TOKEN` 환경 변수를 읽는다.

## Chrome 확장 사용자 인터페이스

| 입력 | 동작 |
|---|---|
| `Alt+Shift+P` | 선택 모드 시작 |
| `Alt+Shift+O` | 선택자 숨김 전역 켜기·끄기 |
| `Alt+Shift+S` | 현재 사이트 프로필 켜기·끄기 |
| `Alt+Shift+E` | 숨긴 요소 잠시 보기(peek) |
| 우클릭 → 인포커터 → 이 요소 숨기기 | 우클릭한 요소를 바로 숨김 규칙으로 저장 |
| 우클릭 → 인포커터 → 선택 모드 시작 | 선택 모드 시작 |

단축키와 메뉴는 `http`·`https` 페이지에서만 동작한다. `chrome://` 같은 페이지에서는 아무 일도 하지 않는다.
