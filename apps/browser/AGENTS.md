# Infocutter App Template Rules

이 디렉토리는 `flutter_inappwebview` 기반 모바일 브라우저에 *사이트별 선택자 DOM 숨김* 을 얹은 인포커터 앱의 strict 템플릿. 원본 [flutter_browser_app](https://github.com/pichillilorenzo/flutter_browser_app) 에서 fork.

## Source Rules

- 새 runtime dependency 추가 시 `pubspec.yaml` 변경에 commit body 사유 명시
- 비즈니스 로직을 `lib/pages/`, `lib/app_bar/`, `lib/main.dart` 같은 UI/엔트리 파일에 직접 박지 말 것 — `lib/infocutter/` 또는 `lib/models/` 로 분리
- ContentBlocker 룰 생성 로직은 `lib/infocutter/content_blocker_factory.dart` 한 곳
- selector 생성/검증 로직은 `lib/infocutter/selector_engine.dart` 한 곳 (Chrome 의 `src/shared/selector.ts` 등가물)
- storage 객체 직접 작성은 `lib/infocutter/storage.dart` 외부에서 금지
- `dart:io` Process / shell injection 금지
- `flutter_inappwebview` 의 `addUserScript` 에 *사용자 입력* 을 직접 `'\'+input+'\''` 보간 금지 — `WebMessageListener` 또는 `JavaScriptHandler` 로 인자 전달
- `ContentBlockerActionType.cssDisplayNone` 외의 액션 추가 시 사유 명시 (예: `block` 은 네트워크 차단 = 권한 확대)
- 사이트별 hack 은 `lib/infocutter/adapters/<host>.dart` 같은 named adapter 뒤로

## Architecture Rules

- `lib/browser.dart`, `lib/webview_tab.dart` — 페이지 lifecycle / 탭 관리만
- `lib/app_bar/`, `lib/pages/` — UI 위젯만
- `lib/infocutter/` — *인포커터 핵심 도메인* (selector, storage, content blocker, picker, profile, scope matcher)
- `lib/models/` — 일반 모델 (브라우저 설정, 즐겨찾기 등)
- `lib/util.dart` — 정말 공통 유틸만. 도메인 로직 침투 금지

## Verification Rules

- `flutter analyze` (또는 fvm 사용 시 `fvm flutter analyze`)
- `flutter test`
- `dart format --output=none --set-exit-if-changed .`
- 최소 하나의 디바이스에서 실제 `flutter run` 후 ContentBlocker 적용 확인 (디버그 콘솔에 selector 매칭 로그)

위 셋 통과 안 하면 "준비됨" 이라고 주장 금지.

## i18n

- 새 사용자-노출 문자열은 `lib/l10n/app_<locale>.arb` 에 키 추가 → `flutter gen-l10n` 으로 dart 코드 생성
- 기본 로케일: `ko`. 추가 권장: `en`, `ja`
- 한글 하드코딩 발견 시 `// FIXME(i18n): T-<ticket>` 마커 + 다음 PR 에서 이관

## Storage

- 모든 영속 데이터는 `lib/infocutter/storage.dart` 의 `InfocutterStore` 통해
- 스키마 변경 시 `STORAGE_VERSION` bump + `migrateV<N-1>ToV<N>` 함수 추가
- chrome-extension 의 `RuleStore` 스키마와 *최대한 호환 유지* — sync 가능성 보장
