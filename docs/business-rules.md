# 비즈니스 규칙

## 용어

- **프로필**: URL matcher 목록과 그 URL에서 적용할 규칙 묶음이다. 선택자 규칙, 텍스트 블록 규칙, AI 규칙은 각자 별도의 프로필 목록을 가진다.
- **카드**: 한 프로필 안에서 함께 켜고 끄는 규칙 묶음이다. 사용자가 선택 모드에서 한 번에 고른 요소들이 한 카드가 된다.
- **규칙 모드**: `hide`는 숨김, `unhide`는 같은 프로필의 숨김에서 빼는 예외다.
- **frameScope**: 규칙이 적용되는 문서다. `null`이면 최상위 문서, 문자열이면 그 iframe의 `origin + pathname`이다.
- **감시 대상(watch target)**: 이름과 별칭 목록이다. 페이지에 나타나면 표시하고 증거로 남길 수 있다. 숨김 규칙과는 별개다.
- **오브젝트 태그**: 텍스트 블록 규칙에 붙는 분류 태그다. 전역 설정의 숨김 태그와 겹칠 때만 규칙이 동작한다.

## 선택자 규칙 저장소

현재 모양은 `{ version: 4, settings: { globalEnabled }, profiles: [...] }`이다. 프로필은 `id`, `name`, `enabled`, `matchers`, `cards`, `rules`, `sourceTemplateSlug`, `updatedAt`을 가진다. 규칙은 `cardId`, `cardName`, `selector`, `mode`, `frameScope`, `createdAt`을 가진다.

읽을 때 Chrome은 다음처럼 정규화한다.

| 입력 | 결과 |
|---|---|
| `version`이 4 또는 3 | `profiles`를 그대로 읽는다 |
| `version`이 1 또는 2 | `sites[hostname]`마다 matcher `https://<hostname>/*` 하나를 가진 프로필을 만든다. `rules`가 없으면 `selectors`를 읽는다 |
| 그 밖의 값, `version` 없음, 객체가 아님 | 빈 저장소(`globalEnabled: true`, 프로필 0개)를 돌려준다 |
| 규칙이 문자열 하나 | `hide` 모드, 카드 이름 `기본 카드`, `frameScope: null`인 규칙으로 바꾼다 |
| `selector`가 문자열이 아닌 규칙 | 버린다 |
| 프로필에 `cards` 배열이 없음 | 규칙의 `cardId`로 카드를 만들어 낸다 |
| 규칙의 `cardId`에 해당하는 카드가 없음 | 그 규칙 이름으로 카드를 새로 만든다. 카드가 있으면 규칙의 `cardName`을 카드 이름으로 맞춘다 |

Flutter는 `version`을 보지 않고 `profiles`만 읽는다. 따라서 version 1·2 형식(`sites`)을 Flutter에 가져오면 규칙이 하나도 들어오지 않는다. 카드가 없는 규칙에 카드를 새로 만드는 보정도 Flutter에는 없다.

같은 `selector`, `frameScope`, `mode`, `cardId`를 가진 규칙은 한 프로필에 두 번 들어가지 않는다.

## URL matcher

matcher가 `scheme://host[:port]/path` 형태이면 다음 규칙으로 비교한다.

- scheme이 `*`이면 `http`와 `https`를 모두 받는다.
- host는 글자 그대로 비교한다. `*.example.com` 같은 서브도메인 와일드카드는 지원하지 않는다. `https://www.naver.com/*`는 `https://m.naver.com/`에 맞지 않는다.
- port를 적지 않으면 모든 port를 받는다.
- path의 `*`는 임의 문자열이다.

host 자리에 `*`가 들어간 `*://*/*`처럼 위 형태에 맞지 않는 matcher는 문자열 전체를 `*` 와일드카드 패턴으로 비교한다. 그래서 `*://*/*`는 모든 URL에 맞는다.

## 프로필 선택과 우선순위

Chrome은 URL마다 **프로필 배열에서 matcher가 맞는 첫 프로필 하나만** 적용한다. 배열 순서가 우선순위이고, options 화면에서 위아래로 옮길 수 있다.

- 선택 모드에서 규칙을 저장하면 현재 URL에 맞는 첫 프로필에 들어간다. 맞는 프로필이 없으면 matcher `<origin>/*`, 이름 `<hostname>`인 프로필을 배열 끝에 새로 만든다.
- 새 프로필은 항상 배열 끝에 붙는다. 앞에 `*://*/*` 같은 넓은 프로필이 있으면 사이트 전용 프로필은 적용되지 않고, 선택 모드로 고른 규칙도 그 넓은 프로필에 들어가 모든 사이트에 적용된다.
- `unhide` 예외는 같은 프로필 안의 `hide` 규칙에만 작용한다. 다른 프로필의 예외는 무시된다.

Flutter는 경로마다 다르다. 사이드바 표시와 JS 런타임 상태는 Chrome처럼 첫 프로필 하나를 쓰지만, ContentBlocker는 URL에 맞는 **모든 활성 프로필**의 `hide` 규칙을 합쳐 적용한다.

## 선택자 규칙 적용

Chrome content script는 frame마다 다음 순서로 판정한다.

1. `settings.globalEnabled`가 `false`이거나 선택된 프로필의 `enabled`가 `false`이면 아무것도 숨기지 않는다.
2. 켜진 카드의 규칙 가운데 `frameScope`가 현재 frame의 값과 정확히 같은 것만 고른다. 최상위 문서는 `null`, iframe은 `origin + pathname`이다. 쿼리 문자열과 해시는 비교하지 않는다.
3. `hide` 규칙이 하나도 없으면 아무것도 숨기지 않는다. `unhide` 규칙만으로는 효과가 없다.
4. `hide` 선택자에 걸린 요소가 `unhide` 선택자에 걸린 요소 자신이거나 그 요소를 품고 있으면 숨기지 않는다.
5. 나머지 요소는 숨긴다. 문법이 틀린 선택자는 오류 없이 무시한다.

Flutter ContentBlocker는 `frameScope`가 `null`인 규칙만 쓴다. iframe 규칙은 ContentBlocker로 적용되지 않는다. 예외는 각 `hide` 선택자에 `:not(<unhide>)`를 붙여 처리하므로, 예외 요소를 **품은** 부모는 Chrome과 달리 숨겨진다.

## 템플릿

템플릿은 `{ version: 1, slug, name, description, matchers, cards: [{ id, name, enabled, note, rules: [{ frameScope, mode, selector }] }] }`이다.

- Chrome에서 템플릿을 적용하면 `sourceTemplateSlug`가 같은 프로필을 찾아 통째로 바꾸고, 없으면 새로 만든다. 카드 id는 `tpl:<slug>:<card id>`가 된다.
- Flutter는 앱에 내장된 템플릿 목록(네이버 홈 광고 2종)을 쓴다. 프로필 id `template-<slug>`로 찾아 바꾸고, 카드 id는 `template-<slug>-<card id>`다. 같은 템플릿이라도 두 플랫폼의 id가 다르다.
- Chrome의 프로필을 템플릿으로 올릴 때 카드 id 앞의 `tpl:<slug>:`를 떼어 낸다.

## 플랫폼 사이 규칙 옮기기

- Flutter는 선택자 규칙 저장소 전체를 Chrome 형식 JSON으로 클립보드에 내보내고, 붙여 넣은 JSON을 가져온다. 가져오기는 프로필 `id`가 같으면 가져온 것으로 덮어쓰고, 다른 프로필은 그대로 두며, `globalEnabled`는 가져온 값으로 바꾼다.
- Chrome에는 규칙 저장소 전체를 JSON으로 내보내거나 가져오는 화면이 없다. Chrome 쪽 교환 수단은 템플릿 서버다.
- 텍스트 블록, 감시 대상, 네트워크 필터, AI 규칙, 증거 기록은 플랫폼 사이에서 옮기지 않는다.

## 텍스트 블록

저장소는 `{ version: 1, settings: { globalEnabled, hiddenObjectTags }, profiles }`이고, `hiddenObjectTags` 기본값은 `["ad"]`다. 규칙은 `keyword`, `minMatchCount`, `fingerprint`, `objectId`, `objectName`, `objectTags`를 가진다.

1. 규칙은 `objectTags`가 비어 있거나 `hiddenObjectTags`와 하나라도 겹칠 때만 동작한다. 태그는 소문자로 바꾸고 `[a-z0-9_-]{1,32}`에 맞지 않으면 버린다.
2. 공백을 한 칸으로 줄이고 소문자로 바꾼 텍스트 노드 하나 안에 `keyword`가 들어 있으면 그 노드에서 가장 가까운 블록 컨테이너를 후보로 잡는다. 여러 노드에 걸친 문구는 잡지 않는다. `script`, `style`, `textarea`, `input` 등 입력·코드 요소 안의 텍스트는 보지 않는다.
3. 후보를 구조 지문(태그, 안정 클래스, 부모 태그, 앞쪽 자식 태그 4개)으로 묶는다.
4. 한 묶음의 블록 수가 `minMatchCount` 이상이고, 규칙의 `fingerprint`가 `null`이거나 묶음 지문과 같을 때만 그 묶음 전체를 숨긴다. `minMatchCount`는 2보다 작게 저장되지 않는다. 따라서 키워드가 한 블록에만 나오면 숨겨지지 않는다.

## 감시와 증거

감시 대상은 이름과 별칭을 소문자로 바꾸고, 두 글자 이상인 것만 검색어로 쓴다. 꺼진 대상은 제외한다. 페이지 텍스트의 공백을 한 칸으로 줄이고 소문자로 바꾼 뒤 부분 문자열로 찾는다.

- `settings.autoMask`가 켜져 있으면 찾은 블록을 흐리게(blur 8px) 가리고 칩을 띄운다.
- 증거는 사용자가 칩에서 저장을 눌렀을 때만 만든다. 자동 저장은 없다. 저장에 성공하면 그 블록을 숨기고, 실패하면 다시 흐리게 하고 재시도 버튼을 띄운다.
- 감시 저장소의 `version`이 1이 아니면 빈 저장소로 읽는다.

증거 한 건은 캡처 시각(ISO-8601), URL, 페이지 제목, 매칭어, HTML 해시, PNG 해시를 담은 manifest와 함께 저장된다. 해시는 모두 SHA-256 16진수다.

| 항목 | Chrome 확장 | Flutter 앱 |
|---|---|---|
| HTML 범위 | 매칭된 블록의 `outerHTML`, 최대 200,000자 | 페이지 전체 HTML(`getHtml`) |
| 화면 | `captureVisibleTab`을 스크롤하며 이어 붙인 전체 페이지 PNG | WebView 스크린샷(실패하면 PNG 없음) |
| 저장 위치 | 다운로드 폴더 `infocutter-evidence/<매칭어>/<시각>.pdf·png·html·manifest.json` | 앱 지원 디렉터리 `infocutter-evidence/<id>/page.html·page.png·summary.pdf·manifest.json` |
| 기록 목록 | IndexedDB `infocutter-evidence` | SharedPreferences |
| 중복 처리 | 같은 URL과 같은 HTML 해시가 이미 있으면 파일을 만들지 않고 `deduped: true`로 응답한다 | 같은 URL과 같은 HTML 해시가 있으면 기존 기록을 돌려준다 |

Chrome PDF 끝에는 "본 자료는 소명 참고자료이며 다툼이 있는 사건에서는 공증·증거보전 신청·디지털 포렌식 등 추가 절차가 필요할 수 있다"는 취지의 고지가 들어간다. 제품 문구에서 증거 파일을 법적 효력이 보장된 증거로 표현하지 않는다.

## 네트워크 필터 (Chrome)

사용자가 붙여 넣은 AdBlock·uBlock 형식 필터 목록을 한 줄씩 해석한다.

| 줄 형식 | 처리 |
|---|---|
| `도메인##선택자` | 이름 `Imported filters <도메인>`(도메인이 없으면 `Imported global filters`) 프로필에 `hide` 규칙으로 넣는다. matcher는 도메인마다 `*://<도메인>/*`, 도메인이 없으면 `*://*/*`다 |
| `도메인#@#선택자` | 같은 방식의 프로필에 `unhide` 규칙으로 넣는다 |
| `##선택자:has-text(...)`, `:contains(...)`, `:-abp-contains(...)` | 텍스트 블록 프로필을 새로 만들고, 괄호 안 문구를 키워드로 쓴다. 선택자 부분은 버린다. 태그는 `ad`, `minMatchCount`는 2다 |
| `#?#`인데 텍스트 조건이 없음 | 가져오지 않는다 |
| `#%#`, `#$#`(스크립트·HTML 주입) | 가져오지 않는다 |
| 그 밖의 줄 | 네트워크 규칙으로 해석해 declarativeNetRequest 규칙으로 바꾼다. 지원하지 않는 수정자가 있으면 이유와 함께 건너뛴다 |

네트워크 규칙 id는 1,000,000부터 1,199,999까지를 인포커터 전용으로 쓰고, 현재 최댓값 다음 번호부터 붙인다. 범위를 넘으면 가져오기 전체가 오류로 끝난다. 저장소가 바뀔 때마다 이 범위의 동적 규칙을 모두 지우고 켜진 규칙만 다시 등록한다. 이 범위 밖의 동적 규칙은 건드리지 않는다.

Flutter는 같은 형식의 네트워크 규칙을 해석해 WebView 수준에서 막는다. http·https URL에 대해 켜진 `@@` 허용 규칙이 하나라도 맞으면 차단하지 않고, 그렇지 않을 때 맞는 차단 규칙이 있으면 막는다. 켜진 허용 규칙이 하나라도 있으면 ContentBlocker 경로는 통째로 쓰지 않고, 탐색 취소와 요청 가로채기 경로로만 막는다.

## AI 마스킹

AI 카테고리는 `violence`, `sexual`, `gore`, `hate`, `shock`, `other` 여섯 개다.

Chrome은 다음 순서로 동작한다.

1. 사용자가 팝업에서 AI 분석을 누를 때만 실행한다. 페이지를 열 때 자동으로 돌지 않는다.
2. API 키가 비어 있으면 `no-api-key`, AI 전역 설정이 꺼져 있으면 `disabled`, 켜진 카테고리가 없으면 `no-categories`로 건너뛴다.
3. content script가 블록을 최대 120개 모으고, 각 블록의 텍스트를 200자로 자른다. 모은 블록이 없으면 `no-blocks`로 건너뛴다.
4. LLM 응답에서 JSON 배열만 뽑는다. 알 수 없는 카테고리는 `other`, 신뢰도는 0~1로 자른다.
5. 켜진 카테고리이면서 신뢰도가 0.6 이상인 결과만 남긴다. 하나라도 남으면 matcher `<origin>/*`의 AI 프로필 규칙을 **통째로 교체**하고, 사용자 확인 없이 바로 숨긴다. 남은 결과가 없으면 기존 AI 규칙을 그대로 둔다.

Flutter는 수동 분석만 한다. 결과는 제안 목록으로 저장되고, 사용자가 승인한 제안만 선택자 `hide` 규칙으로 들어간다.

## 사이트 보호 해제 (Flutter)

사용자는 깨진 사이트에서 호스트 단위로 선택자 숨김·텍스트 블록·네트워크 필터·감시를 잠시 끌 수 있다. 호스트 목록만 저장하고 프로필의 `enabled`는 바꾸지 않는다. 호스트는 정확히 같아야 하며 서브도메인은 따로 취급한다.
