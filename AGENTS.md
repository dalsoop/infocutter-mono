# infocutter-mono

인포커터(Infocutter)는 웹페이지에서 보기 싫은 요소·문구·이름을 사용자가 직접 골라 가리고, 필요할 때 URL·시각·해시가 담긴 증거 파일로 남기는 제품이다. 악플에 지친 사람이 핵심 사용자이고, 데스크톱은 Chrome MV3 확장(`extensions/chrome`), 모바일·macOS·Windows는 Flutter 브라우저 앱(`apps/browser`)이 맡는다. 서버 없이 모든 데이터가 사용자 기기에 저장되는 1인 개발 규모의 공개(public) GitHub 저장소다.

## 프로젝트 구조

```
infocutter-mono/
├── CLAUDE.md                          ← 에이전트 진입점 (AGENTS.md와 같은 내용)
├── AGENTS.md                          ← 에이전트 진입점 (CLAUDE.md와 같은 내용)
├── docs/
│   ├── architecture.md                ← 구성 요소, 데이터 흐름, 외부 의존
│   ├── business-rules.md              ← 규칙 저장소·매칭·텍스트 블록·감시·증거·AI의 동작 규칙
│   ├── security.md                    ← 인증 origin 배제, 권한, 비밀, 자동화 브리지
│   ├── standards.md                   ← 머지 전 게이트와 MUST / MUST NOT
│   ├── engineering-notes.md           ← 함정과 비자명한 메커니즘
│   ├── operations.md                  ← 설치·빌드·검증·패키징 절차
│   ├── contracts.md                   ← 규칙 JSON, 메시지, 템플릿 서버, 자동화 브리지 계약
│   └── tracking/
│       ├── status.md                  ← 구현·검증 현황
│       ├── findings.md                ← 미해결 문제
│       └── decisions/
│           ├── index.md               ← 결정 목록
│           └── NNNN-*.md              ← 개별 결정
├── extensions/
│   └── chrome/
│       ├── AGENTS.md                  ← MV3 확장: 레이어, content script 순서, 게이트
│       └── packages/
│           └── AGENTS.md              ← content script용 IIFE 도메인 패키지 4종
├── apps/
│   └── browser/
│       ├── AGENTS.md                  ← Flutter 브라우저 앱: 레이어, WebView 주입, 게이트
│       ├── .codex/
│       │   └── AGENTS.md              ← 옛 진입점. 정본이 flutter-app-mono 쪽이라고 적혀 있다(정본 저장소 미결정, 따르지 않는다)
│       └── mcp/
│           └── AGENTS.md              ← 디버그 자동화 브리지를 감싼 MCP 서버
└── packages/
    ├── ext-build/
    │   └── AGENTS.md                  ← MV3 빌드 파이프라인 공용 모듈
    └── ext-runtime/
        └── AGENTS.md                  ← MV3 런타임 스캐폴드 원본 (이 저장소 안 소비자 없음)
```

## 절대 규칙

1. 인증 origin(`accounts.google.com`, `login.microsoftonline.com`, `appleid.apple.com`와 그 서브도메인, `github.com/login`, `gitlab.com/users/sign_in` 이하)에서는 Flutter 앱이 JS 주입, 요청 가로채기, ContentBlocker를 하나도 켜지 않는다. 판정은 `isAuthOrigin` 한 곳에서만 한다.
2. 선택자 규칙 저장소(`infocutter.ruleStore`, version 4) JSON 모양은 Chrome과 Flutter가 공유한다. 한쪽에서 필드를 추가·변경하면 Chrome `normalizeRuleStore`와 Flutter `RuleStoreCodec`을 같은 변경 안에서 함께 고치고 양쪽 테스트를 추가한다.
3. 저장소 스키마 버전을 올릴 때는 이전 버전 입력을 읽는 분기를 normalize에 먼저 넣는다. 알 수 없는 버전을 만나면 빈 저장소가 반환되어 사용자 규칙이 조용히 사라진다.
4. 저장소는 공개 상태다. API 키, 서명 키, 템플릿 서버 토큰, 자동화 브리지 토큰을 코드·템플릿·문서에 커밋하지 않는다.
5. 머지 전 게이트(Chrome `npm run pipe:check`, Flutter `analyze`·`test`·생성물 동기 검사)를 직접 돌려 통과를 확인하기 전에는 완료를 주장하지 않는다.

## 작업 전에 읽을 것

- 항상: `docs/standards.md`, `docs/engineering-notes.md`, 작업할 모듈의 `AGENTS.md`.
- 규칙 저장소 스키마나 가져오기·내보내기를 바꿀 때: `docs/business-rules.md`의 규칙 저장소·프로필 우선순위 절과 `docs/contracts.md`의 규칙 저장소 JSON 절.
- Chrome content script 파일을 추가·삭제하거나 이름을 바꿀 때: `docs/engineering-notes.md`의 content script 주입 순서 항목.
- Flutter WebView 주입, `shouldInterceptRequest`, ContentBlocker를 건드릴 때: `docs/security.md`의 인증 origin 절.
- 증거 캡처(PDF·PNG·HTML·manifest)를 건드릴 때: `docs/business-rules.md`의 증거 절. Chrome과 Flutter가 해시 대상을 다르게 잡는다.
- AI 마스킹을 건드릴 때: `docs/security.md`의 외부 전송 데이터 절.
- 자동화 브리지나 MCP 서버를 건드릴 때: `docs/security.md`의 자동화 브리지 절.

## 문제 처리

다음은 발견 즉시 사용자에게 알린다.

- 인증 origin 페이지에 스크립트가 주입되거나 요청이 가로채지는 경로가 생긴 경우
- 저장소 버전 처리 오류 등으로 사용자의 규칙·감시 대상·증거 기록이 지워지거나 덮어써질 수 있는 경우
- 비밀 값이 커밋되었거나 커밋 직전인 경우
- 증거 파일의 해시와 manifest가 서로 맞지 않게 되는 경우
- 자동화 브리지가 release 빌드에서 열리거나, 인증 없이 민감한 동작을 실행할 수 있게 되는 경우

그 밖의 문제는 `docs/tracking/findings.md`에 조건, 증상, 영향 범위, 지금 못 고치는 이유를 적는다.
