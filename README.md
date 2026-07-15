# SkillBook

설치된 Claude Code 스킬을 보여주는 macOS 메뉴바 치트시트 앱.

Claude 데스크톱 앱이 최전면에 오면 플로팅 패널이 자동으로 떠서, 어떤 스킬이 있고
언제 발동되는지 참조할 수 있다. [MacKey](../MacKey)(단축어 치트시트)를 계승한 앱으로,
단축어가 Claude Code 스킬로 이관되면서 대상만 단축어 → 스킬로 바뀌었다.

## 동작

- **자동 표시**: Claude 데스크톱 앱이 앞에 오면 패널 표시, 다른 앱으로 전환하면 숨김.
- **3단 구조**: 카테고리 ▸ 스킬 ▸ 설명.
  - 카테고리 = "내 스킬" + 설치된 플러그인별 하나씩 (개수 뱃지 표시).
  - 카테고리 펼침 상태는 재시작 후에도 유지 (첫 실행은 "내 스킬"만 펼침).
- **`/이름` 복사**: 스킬 이름을 클릭하면 `/git-flow` 형식이 클립보드에 복사된다.
  자동발동이 안 될 때 확정적으로 스킬을 부르는 백업 수단.
- **읽기 전용**: `~/.claude` 아래에 어떤 쓰기도 하지 않는다.

## 데이터 소스

별도 저장소 없이 디스크를 직접 읽는다. 패널이 표시될 때마다 재스캔하므로
스킬을 추가·수정하면 바로 반영된다.

| 카테고리 | 경로 |
|---|---|
| 내 스킬 | `~/.claude/skills/*/SKILL.md` |
| 플러그인 | `~/.claude/plugins/installed_plugins.json`의 각 `installPath/skills/*/SKILL.md` |

각 SKILL.md의 YAML frontmatter에서 `name`/`description`만 파싱한다
(한 줄 값과 `>-` 접기 블록 지원, 원문 그대로 표시). `skills/` 폴더가 없는
플러그인(커맨드·훅 전용)은 카테고리가 생략된다.

**번역 오버라이드**: `~/.claude/skillbook-ko.json`에 `{ "스킬이름": "한국어 설명" }`
매핑이 있으면 해당 스킬의 설명만 한국어로 교체된다. 파일이 없거나 매핑에 없는
스킬은 원문 폴백. 번역 파일 갱신은 Claude Code에게 "번역 파일 갱신해줘"로 요청.

## 구조

| 파일 | 역할 |
|---|---|
| `SkillBookApp.swift` | AppDelegate, 상태 아이템, 메뉴 (패널 보기 / 스킬 폴더 열기 / 새로고침 / 종료) |
| `SkillStore.swift` | 카테고리 목록 조립 (내 스킬 먼저, 플러그인 알파벳순) |
| `SkillScanner.swift` | frontmatter 파서 + 폴더 스캐너 + installed_plugins.json 파서 (순수 함수) |
| `Skill.swift` | `Skill` / `SkillCategory` 모델 |
| `SkillListView.swift` | 3단 disclosure 리스트 UI |
| `PanelController.swift` | 플로팅 패널 (MacKey 이식 — 위치 기억, 콘텐츠 맞춤 높이) |
| `AppDetector.swift` | Claude 데스크톱 앱 최전면 감지 (MacKey 이식, 무수정) |
| `SkillBookMenub.swift` | menub 허브 통합 (3계약) |

- Dock 아이콘 없는 `LSUIElement` accessory 앱, App Sandbox 꺼짐(`~/.claude` 읽기 필요).
- [menub](../Menub) 허브 위성 앱: 매니페스트 기록, `skillbook://action/<id>` 라우팅,
  허브 관리 중이면 자기 상태 아이콘 생략. MenubKit은 로컬 패키지(`../Menub/MenubKit`) 의존.

## 빌드 & 실행

```bash
xcodebuild -project SkillBook.xcodeproj -scheme SkillBook \
  -configuration Debug -derivedDataPath build build
open build/Build/Products/Debug/SkillBook.app
```

테스트 (Swift Testing, 14개):

```bash
xcodebuild test -project SkillBook.xcodeproj -scheme SkillBook \
  -destination 'platform=macOS' -derivedDataPath build -only-testing:SkillBookTests
```

## 문서

- 설계 스펙: [docs/superpowers/specs/2026-07-15-skillbook-design.md](docs/superpowers/specs/2026-07-15-skillbook-design.md)
- 구현 계획: [docs/superpowers/plans/2026-07-15-skillbook.md](docs/superpowers/plans/2026-07-15-skillbook.md)
