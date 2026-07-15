# SkillBook 설계 스펙 (2026-07-15)

MacKey(단축어 치트시트)를 계승하는 **스킬 치트시트** macOS 메뉴바 앱.
Claude 데스크톱 앱이 최전면에 오면 플로팅 패널로 설치된 Claude Code 스킬 목록을 띄워,
어떤 스킬이 있고 언제 발동되는지 참조하고, 필요하면 `/이름`을 복사해 확정 발동시킨다.

## 결정 사항 (브레인스토밍 확정)

- **역할**: 읽기 전용 스킬 치트시트. 스킬 생성·편집·삭제·토글 없음 (스킬 관리는 Claude Code로).
- **데이터 소스**: `~/.claude` 폴더 직접 읽기. 불러오기/내보내기/내부 복사본 없음.
- **표시 범위**: 개인 스킬(`~/.claude/skills/`) + 설치된 플러그인 스킬 전부.
- **프로젝트 형태**: 기존 MacKey 저장소와 별개의 새 저장소 `~/Developer/SkillBook`
  (Xcode 프로젝트, 이미 스캐폴드 존재). MacKey 코드를 복사해 개조하되 MacKey 저장소는 건드리지 않음.
- **구현 접근**: 재활용+감량 — 패널·감지기·리스트 UI·menub 통합은 복사, 데이터 층만 신규로 얇게.
- **menub 통합**: 유지 (id/scheme `skillbook`).

## 아키텍처

- Dock 아이콘 없는 메뉴바 앱 (`NSApplication.setActivationPolicy(.accessory)`), macOS 13+.
- **App Sandbox 끔** — `~/.claude` 읽기 필요. 개인용 앱이므로 문제 없음.
- 기존 Xcode 템플릿의 `WindowGroup`/`ContentView` 제거, MacKey의 AppDelegate 패턴 이식.
- MenubKit 로컬 패키지(`../Menub/MenubKit`) 의존성을 Xcode 프로젝트에 추가.

### 파일 구성

| 파일 | 출처 | 내용 |
|---|---|---|
| `SkillBookApp.swift` | MacKeyApp.swift 개조 | AppDelegate, 상태 아이템, 메뉴("스킬 폴더 열기", "새로고침", "종료"). 설정창 없음 |
| `PanelController.swift` | 그대로 복사 | FloatingPanel 포함. UserDefaults 키만 `SkillBook.*` |
| `AppDetector.swift` | 그대로 복사 | Claude 데스크톱 앱 최전면 감지 → 패널 표시/숨김 |
| `SkillListView.swift` | ShortcutListView 개조 | 아래 UI 구조 참고 |
| `Skill.swift` | 신규 | 모델: `name`, `description`, `category`(내 스킬/플러그인명), `directoryURL`, `invocation`(`/name`) |
| `SkillStore.swift` | 신규 | 폴더 스캔 + frontmatter 파서, `ObservableObject` |
| `SkillBookMenub.swift` | MenubIntegration 개조 | menub 위성 계약 3개, id `skillbook` |

복사하지 않는 것: `ShortcutStore`, `ShortcutParser`, `SettingsView` (불러오기/내보내기/편집/검증 전부 폐기).

### UI 구조 — 3단계 disclosure

```
카테고리 ▸ (펼침) 스킬 ▸ (펼침) description
```

- **카테고리 행**: "내 스킬" + 플러그인별 하나씩(설치 목록에서 자동 생성). 개수 뱃지 표시
  (예: `superpowers (17)`). 클릭으로 접기/펼치기. 펼침 상태는 UserDefaults에 기억,
  첫 실행 기본값은 "내 스킬"만 펼침.
- **스킬 행**: 스킬 이름. 이름 클릭 = `/이름`(예: `/git-flow`)을 클립보드에 복사 + "복사됨" 피드백.
  자동발동이 안 될 때 확정적으로 부르는 백업 수단. 화살표 클릭 = 펼쳐서 description 표시.
- 패널 크기·위치·높이 조절 동작은 MacKey와 동일 (위 고정, 아래로 확장, 위치 기억).

## 데이터 흐름 (읽기 전용, 단방향)

1. 트리거: 앱 실행 시, 패널이 표시될 때마다, 메뉴 "새로고침" 시 → `SkillStore.reload()`.
2. 스캔 대상:
   - `~/.claude/skills/*/SKILL.md` → "내 스킬" 카테고리
   - `~/.claude/plugins/installed_plugins.json`의 각 항목 `installPath/skills/*/SKILL.md`
     → 해당 플러그인명 카테고리
3. 각 SKILL.md에서 YAML frontmatter(`---` 블록)의 `name`, `description` 두 키만 추출.
   본문은 읽지 않는다. 정식 YAML 파서 불필요 — 단순 라인 파싱. 단, 두 형태를 지원해야 한다
   (2026-07-15 실측: 설치된 44개 SKILL.md 전수 조사):
   - 한 줄 값: `description: 텍스트` 또는 `description: "텍스트"` (플러그인 스킬 전부)
   - 접기 블록: `description: >-` 뒤 들여쓰기된 여러 줄 → 공백으로 이어붙임 (개인 스킬 4개)
   description은 원문 그대로 표시한다 (요약·가공 없음).
4. 파일 감시(FSEvents) 없음. 패널 표시 시마다 재스캔으로 충분 (스킬 ~30개, 밀리초 단위).

## 번역 오버라이드 (2026-07-15 추가)

영어 플러그인 스킬 설명을 한국어로 보여주기 위한 선택적 오버라이드.

- `~/.claude/skillbook-ko.json` — `{ "스킬이름": "한국어 설명" }` 매핑.
- reload 시 매칭되는 스킬의 **설명만** 교체. 이름·카테고리는 그대로.
- 파일이 없거나 깨졌거나 매핑에 없는 스킬은 **원문 폴백** (앱은 항상 정상 동작).
- 번역 파일 생성·갱신은 Claude Code가 수행 (새 스킬 설치 후 "번역 파일 갱신해줘").
  앱은 여전히 읽기 전용 — 번역 파일을 쓰지 않는다.

## 에러 처리 — 관대하게, 숨기지 않는다

기존 MacKey의 "검증 실패 → 제외 + 사유 알림" 모델은 폐기.
설치된 스킬을 보여주는 것이므로 불완전해도 표시하는 쪽이 낫다.

- frontmatter에 `name` 없음 → 폴더명을 이름으로 사용.
- `description` 없음 → "(설명 없음)" 표시.
- `installed_plugins.json` 없음/파싱 실패 → 개인 스킬만 표시, 앱은 정상 동작.
- `~/.claude/skills/` 없음 → 빈 상태 문구.
- 플러그인 `installPath`에 `skills/` 폴더 없음 → 해당 플러그인 카테고리 생략.
  (실측: 현재 설치 4개 중 skills 보유는 superpowers·frontend-design뿐.
  code-review는 커맨드, security-guidance는 훅 형태라 치트시트에 안 나타나는 게 정상.)

## 테스트

- 기존 `SkillBookTests` 타깃 활용.
- frontmatter 파서: 정상/name 누락/description 누락/frontmatter 없음/여러 줄 description 케이스.
- 폴더 스캐너: 임시 디렉토리에 fixture SKILL.md를 만들어 스캔 결과 검증
  (개인+플러그인 혼합, installed_plugins.json 파싱 포함).
- UI·패널·감지기: 검증된 MacKey 코드 이식이므로 수동 확인.

## 범위 밖 (명시적 제외)

- 스킬 생성·편집·삭제, 활성화 토글, `.skill` 패키징/설치 도우미
- SKILL.md 본문 전문 표시 (필요 시 추후 확장)
- 파일 감시(FSEvents), 검색 기능
