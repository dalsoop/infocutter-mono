# packages/ext-runtime: MV3 런타임 스캐폴드 원본

## 범위

`@vibecode/ext-runtime` 패키지다. MV3 확장용 i18n 함수 `t`, `chrome.storage` 설정 저장소 팩토리 `createSettingsStore`, 메시지 클라이언트 `sendRuntimeMessage`·`isExtensionContextValid`, 메시지 버스 `createMessageBus`의 원본 소스를 둔다.

이 저장소 안에는 이 패키지를 쓰는 코드가 없다. `extensions/chrome`도 import하지 않는다. `sync-consumers.mjs`가 복사하려는 소비자(`vibecode-chrome-extension-seo-check`, `vibecode-chrome-extension-youtube-evaluator`)는 이 저장소에 없다.

## 불변 조건

- 소비자는 번들러 없이 이 소스를 각자 `packages/ext-runtime/src`에 복사해 상대 경로로 import하는 방식을 전제로 한다. MV3 popup과 service worker가 bare specifier(`@vibecode/ext-runtime`)를 풀지 못하기 때문이다. 따라서 이 소스는 다른 패키지를 import하지 않는다.
- `sync-consumers.mjs`는 저장소 루트 바로 아래의 소비자 디렉터리를 가정한다. 이 저장소에서 실행하면 존재하지 않는 경로에 디렉터리를 만든다. 소비자가 생기기 전에는 실행하지 않는다.
- 메시지 응답 봉투는 `{ ok, data, error }` 모양이다. 이 모양을 바꾸면 복사본을 쓰는 모든 확장이 깨진다.

## 테스트

- 자동 테스트는 없다. 이 저장소에서 이 패키지를 바꿔도 게이트로 확인되는 것이 없으므로, 소비자를 이 저장소에 들이기 전에는 수정하지 않는다.
