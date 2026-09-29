# 0001. Flutter 앱은 인증 origin에서 인포커터 기능을 모두 끈다

- 날짜: 2026-08-04 (이전 저장소 `flutter-app-mono` 커밋 `7f4a6c8`)
- 상태: 유효

## 배경

Google 등 여러 IdP는 임베디드 WebView 안의 계정 로그인을 정책으로 막는다(`403 disallowed_useragent`). 사용자는 이 403 화면을 앱 버그로 오인했다. 그 정책이 막으려는 위협은 인증 페이지에 스크립트를 넣고 요청을 가로채는 앱인데, 인포커터 앱은 모든 페이지에 UserScript를 넣고 요청을 가로챈다.

## 결정

인증 origin(`accounts.google.com`, `login.microsoftonline.com`, `appleid.apple.com`와 그 서브도메인, `github.com/login`, `gitlab.com/users/sign_in` 이하)에서는 JS 주입, 요청 가로채기, ContentBlocker를 모두 끄고 안내 배너를 띄운다. 판정은 `lib/infocutter/auth_origin_policy.dart`의 순수 함수 `isAuthOrigin` 한 곳에서 한다. 서브도메인은 점 경계로만 인정해 `accounts.google.com.evil.com`, `evilaccounts.google.com`은 인증 origin으로 보지 않는다.

## 검토한 대안

- **User-Agent 위장**: 쓰지 않는다. 앱은 UA를 위장하지 않는다는 방침을 가지며, 2026-08-04 측정에서 Android WebView가 `Sec-CH-UA`에 `"Android WebView"`를 스스로 붙이는 것이 확인되어 UA 문자열을 바꿔도 WebView라는 사실을 숨길 수 없었다.
- **`X-Requested-With` 헤더 끄기**: 표준 경로인 `WebViewFeature.REQUESTED_WITH_HEADER_ALLOW_LIST`가 측정 환경의 WebView에서 지원되지 않았다(`supported=false`).

## 결과

- 인증 페이지에서는 숨김, 텍스트 블록, 감시, 네트워크 필터가 동작하지 않는다. 이 예외를 좁히는 변경은 로그인 차단을 다시 부를 수 있다.
- Google 계정 로그인이 된다고 보장하지 못한다. 실기기에서 자격 증명 제출 이후 단계는 확인되지 않았다.
- 새 IdP를 지원하려면 `isAuthOrigin`의 목록에 넣고 판정 테스트를 추가해야 한다. 다른 파일에서 따로 판정하면 끄는 지점 가운데 일부가 빠진다.
