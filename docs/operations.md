# 운영

## 준비물

| 도구 | 필요한 곳 | 확인한 버전 (2026-09-30) |
|---|---|---|
| Node.js, npm | Chrome 확장 빌드·테스트, Flutter `tool/js_test.mjs`, MCP 서버 | Node 24.15.0 (템플릿 서버 Docker 이미지는 `node:22-alpine`, MCP 서버는 Node 18 이상 필요) |
| Chrome 120 이상 | 확장 실행 | manifest `minimum_chrome_version` |
| Flutter SDK (fvm으로 관리) | Flutter 앱 | Flutter 3.44.0 stable, Dart 3.12.0. `pubspec.yaml` 요구치는 Flutter 3.24.0 이상, Dart `^3.5.0` |
| Xcode | iOS·macOS 앱, Safari 확장 변환 | `xcrun safari-web-extension-converter` 포함 |
| Android SDK, Java 17 | Android 앱 | 릴리스 워크플로 기준 Java 17 |
| `zip` | 확장 패키징 | macOS 기본 |

## Chrome 확장

모든 명령은 `extensions/chrome`에서 실행한다. `./infocutter <명령>`은 `npm run pipe:<명령>`을 부르는 얇은 래퍼다.

```sh
cd extensions/chrome
npm install              # npm ci는 lock 파일 경로 불일치로 실패한다
./infocutter doctor      # Node 버전, manifest, 필수 권한 점검
./infocutter build       # dist/ 정리 → 패키지 컴파일 → tsc → dist 조립
```

`npm install`이 먼저여야 한다. 그 전에 `build`를 돌리면 `@vibecode/ext-build`를 찾지 못해 실패한다.

Chrome에 올리기:

1. `./infocutter build` (또는 빌드 후 안내만 출력하는 `./infocutter dev`)
2. `chrome://extensions`에서 개발자 모드를 켠다.
3. "압축해제된 확장 프로그램을 로드합니다"로 `extensions/chrome/dist`를 고른다.
4. 코드를 고친 뒤에는 다시 빌드하고 확장 카드의 새로고침을 누른다. 열려 있던 탭은 새로 고쳐야 새 content script가 붙는다.

자주 쓰는 명령:

| 명령 | 하는 일 |
|---|---|
| `./infocutter watch` | 파일 변경 때마다 `pipe:build`를 다시 돈다 |
| `./infocutter check` | lint → typecheck → 빌드 → 테스트 |
| `./infocutter package` | 빌드 후 `dist-package/infocutter-v<package.json version>.zip`을 만든다 |
| `./infocutter rc` | 전부 지우고 다시 빌드 → doctor → check → package |
| `./infocutter reset` | `dist`, `dist-package`, `packages-dist`, `packages/*/dist`를 지운다 |

버전을 올릴 때는 `package.json`의 `version`과 `public/manifest.json`의 `version`을 함께 바꾼다. zip 이름은 `package.json`을, 스토어에 보이는 버전은 manifest를 따른다.

### iOS Safari 확장

```sh
cd extensions/chrome
npm run pipe:safari            # dist 빌드 → safari-ios/ 에 iOS 전용 Xcode 프로젝트 생성
SAFARI_TEAM_ID=<팀 ID> npm run pipe:safari-archive   # Archive → .ipa export
```

`safari-ios/`는 빌드 산물이며 gitignore 대상이다. 매번 converter로 다시 만든다. Archive 단계는 Apple Distribution 인증서와 프로비저닝 프로파일이 키체인에 있어야 하므로 사람이 준비해야 한다. `SAFARI_SIGNING_IDENTITY`로 서명 ID를 바꿀 수 있다(기본값 `Apple Distribution`).

### 템플릿 서버 (선택)

options 화면의 템플릿 탭은 템플릿 서버에서 템플릿을 받는다. 서버 스크립트는 `./infocutter templates`와 `compose.templates.yml`로 띄우게 되어 있지만, 현재는 `scripts/lib.mjs`가 없어 시작하지 못한다. 서버 설정은 `INFOCUTTER_TEMPLATE_*` 환경 변수로 받는다. 템플릿 서버 설정에는 보안 이슈 있음, 비공개 추적. 서버는 루프백 주소에서만 띄운다.

## Flutter 앱

모든 명령은 `apps/browser`에서 실행한다. 이 앱에는 `.fvmrc`가 없으므로 fvm 전역 버전을 정해 두거나 fvm 캐시의 SDK 경로를 직접 쓴다.

```sh
cd apps/browser
fvm global stable            # 한 번만. 이미 전역 버전이 있으면 생략
fvm flutter pub get
fvm flutter run -d macos     # 또는 iOS 시뮬레이터, Android 에뮬레이터 id
```

`pub get`이 먼저여야 한다. `flutter_inappwebview`는 git 저장소의 고정 커밋에서 받으므로 네트워크가 필요하다.

생성물 다시 만들기:

```sh
fvm dart run tool/generate_user_scripts.dart     # assets/js → lib/infocutter/generated/user_scripts.g.dart
fvm dart run tool/generate_theme_tokens.dart     # design/design-tokens.json → lib/theme/infocutter_tokens.g.dart
fvm flutter gen-l10n                             # lib/l10n/*.arb → lib/l10n/generated/
```

### 디버그 자동화

디버그 빌드는 루프백 주소에 자동화 브리지를 띄운다. 브리지 설정은 `--dart-define`으로 넘긴다. 브리지 접근 제어에는 보안 이슈 있음, 비공개 추적. 디버그 앱은 신뢰하는 기기에서만 띄운다.

MCP 서버로 연결하려면 `apps/browser/mcp`에서 `npm install` 후 `node smoke.mjs`로 앱까지의 연결을 확인한다. 실기기라면 먼저 `adb reverse`(Android)나 `iproxy`(iOS)로 브리지 포트를 넘긴다.

`tool/infocutter_control.dart`는 VM service URI로 실행 중인 앱의 `ext.infocutter_app.control` 확장을 호출한다.

### Android 릴리스 빌드

릴리스 서명 설정(`android/key.properties`와 keystore)은 저장소 밖 비밀 저장소에서 빌드 직전에 만든다. 두 파일은 gitignore 대상이며 커밋하지 않는다. 서명 값의 정본은 비공개 저장소 principal-secrets-mono(SOPS + age)이고, `tools/materialize-signing.sh`가 그 체크아웃에서 `sops --decrypt --extract`로 읽는다. 체크아웃 경로는 환경 변수 `PRINCIPAL_SECRETS_ROOT`로 넘기며 기본값이 없다. age 식별자 파일은 `SOPS_AGE_KEY_FILE`(기본 `~/.config/sops/age/macbook-se.txt`)이다. `sops`, 식별자 파일, 암호문 중 하나라도 없으면 스크립트가 이유를 출력하고 멈춘다. 예전에 쓰던 Infisical은 퇴역했으므로 `INFISICAL_SIGNING_*` 변수는 더 이상 쓰지 않는다.

```sh
cd apps/browser
PRINCIPAL_SECRETS_ROOT=<principal-secrets-mono 체크아웃> tools/materialize-signing.sh
```

```sh
cd apps/browser
fvm flutter build appbundle --release
```

`key.properties`가 없으면 `android/app/build.gradle`의 release 서명 설정 값이 모두 비고, release 빌드는 스토어에 올릴 수 있는 서명을 얻지 못한다.

### macOS 빌드가 플러그인 컴파일에서 멈출 때

Xcode 26에서 `flutter_inappwebview_macos`의 `WebAuthenticationSession` 오류가 나면 `tool/patch_macos_inappwebview.sh`를 한 번 실행하고 다시 빌드한다. `pub cache`를 새로 받으면 다시 실행해야 한다.

## 배포

- Chrome 웹 스토어: `./infocutter rc`로 만든 `dist-package/*.zip`을 올린다. 업로드는 사람이 한다.
- iOS Safari 확장: `pipe:safari` → `pipe:safari-archive` → App Store Connect(TestFlight) 업로드. 업로드는 사람이 한다.
- Flutter 앱: 이 저장소에서 실행되는 자동 배포는 없다. `apps/browser/.github/workflows/main.yml`은 하위 디렉터리에 있어 GitHub가 읽지 않는다.

## 데이터 초기화

서버 데이터는 없다. 개발 중 사용자 데이터를 비우려면 다음을 쓴다.

- Chrome: 확장을 제거했다가 다시 올리면 `chrome.storage.local`과 IndexedDB `infocutter-evidence`가 비워진다. 다운로드 폴더의 `infocutter-evidence/` 파일은 따로 지운다.
- Flutter: 앱을 지우거나 기기 설정에서 앱 데이터를 지운다. 증거 파일은 앱 지원 디렉터리 `infocutter-evidence/` 아래에 있다.
