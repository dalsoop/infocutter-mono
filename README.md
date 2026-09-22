# infocutter-mono

Infocutter 공식 모노레포 — 보고 싶은 것만 남기는 브라우저 및 확장 프로그램 스위트.

## 프로젝트 구성

- **`apps/browser`**: [Infocutter Browser](apps/browser) — Flutter 기반 모바일/macOS 브라우저. 사이트별 DOM 요소 선택 차단, AI 마스킹, 증거 캡처 지원.
- **`extensions/chrome`**: [Infocutter Chrome Extension](extensions/chrome) — Manifest V3 기반 브라우저 확장 프로그램.
- **`packages/`**: 확장 프로그램 런타임 및 빌드 공통 패키지 (`ext-build`, `ext-runtime`).

## 라이선스

MIT License
