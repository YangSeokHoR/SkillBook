# SkillBook 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Claude 데스크톱 앱이 최전면에 오면 설치된 Claude Code 스킬 목록(개인+플러그인)을 플로팅 패널로 보여주는 macOS 메뉴바 앱.

**Architecture:** 기존 MacKey 앱(`/Users/seokho/Developer/MacKey`)의 패널·감지기·menub 통합을 복사해 재활용하고, 데이터 층만 신규로 얇게 짠다(폴더 스캔 + frontmatter 파서, 읽기 전용). UI는 카테고리 ▸ 스킬 ▸ 설명 3단계 disclosure.

**Tech Stack:** Swift 5 / SwiftUI + AppKit(NSPanel, NSWorkspace), Xcode 프로젝트(objectVersion 77, fileSystemSynchronizedGroups), Swift Testing(@Test/#expect), 로컬 패키지 MenubKit.

**Spec:** `docs/superpowers/specs/2026-07-15-skillbook-design.md`

## Global Constraints

- 저장소: `/Users/seokho/Developer/SkillBook` (모든 경로는 여기 기준). MacKey 저장소는 **읽기만** 하고 절대 수정하지 않는다.
- `SkillBook/` 폴더는 fileSystemSynchronizedGroups라 **파일을 만들면 자동으로 타깃에 포함**된다. pbxproj에 파일 등록 불필요.
- 읽기 전용 앱: `~/.claude` 아래에 어떤 쓰기도 하지 않는다.
- description은 SKILL.md 원문 그대로 표시. 요약·가공 금지.
- 개인 스킬 카테고리명은 고정 문자열 `내 스킬` (`SkillStore.personalCategoryName`).
- 주석·UI 문구는 한국어 (MacKey 관례 유지).
- 테스트는 Swift Testing(`import Testing`, `@Test`, `#expect`). XCTest 아님. 앱 모듈이 기본 MainActor 격리(`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`)이므로 **테스트 struct에 `@MainActor`를 붙인다**.
- 빌드: `xcodebuild -project SkillBook.xcodeproj -scheme SkillBook -configuration Debug -derivedDataPath build build`
- 테스트: `xcodebuild test -project SkillBook.xcodeproj -scheme SkillBook -destination 'platform=macOS' -derivedDataPath build -only-testing:SkillBookTests`
- 커밋 메시지 끝에 `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.

---

### Task 1: 프로젝트 설정 (샌드박스·Info.plist·MenubKit·gitignore)

**Files:**
- Create: `SkillBook/Info.plist`
- Create: `.gitignore`
- Modify: `SkillBook.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: 없음 (첫 태스크)
- Produces: 이후 모든 태스크의 빌드 환경 — 샌드박스 꺼짐(`~/.claude` 읽기 가능), `import MenubKit` 가능, `skillbook://` URL 스킴 등록, LSUIElement 앱.

- [ ] **Step 1: .gitignore 생성**

```
build/
DerivedData/
xcuserdata/
.DS_Store
```

- [ ] **Step 2: SkillBook/Info.plist 생성** (LSUIElement + URL 스킴. GENERATE_INFOPLIST_FILE=YES와 병용하면 빌드 시 병합된다)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>LSUIElement</key>
	<true/>
	<key>CFBundleURLTypes</key>
	<array>
		<dict>
			<key>CFBundleURLName</key>
			<string>ysh.SkillBook</string>
			<key>CFBundleURLSchemes</key>
			<array>
				<string>skillbook</string>
			</array>
		</dict>
	</array>
</dict>
</plist>
```

- [ ] **Step 3: pbxproj — 앱 타깃 두 구성(Debug `C3F98F6F…`, Release `C3F98F70…`) 수정**

두 구성 모두에서 (Edit로 각각):

```
ENABLE_APP_SANDBOX = YES;
```
→
```
ENABLE_APP_SANDBOX = NO;
INFOPLIST_FILE = SkillBook/Info.plist;
```

- [ ] **Step 4: pbxproj — MenubKit 로컬 패키지 참조 추가** (4군데)

(a) `/* Begin PBXFileReference section */` 바로 **앞**에 삽입:

```
/* Begin PBXBuildFile section */
		AB00000000000000000000B3 /* MenubKit in Frameworks */ = {isa = PBXBuildFile; productRef = AB00000000000000000000B2 /* MenubKit */; };
/* End PBXBuildFile section */

```

(b) 앱 타깃의 Frameworks 빌드 페이즈(`C3F98F4A3006A06E00430473`)의 `files = (` 안에:

```
				AB00000000000000000000B3 /* MenubKit in Frameworks */,
```

(c) 앱 타깃(`C3F98F4C3006A06E00430473 /* SkillBook */`)의 `packageProductDependencies = (` 안에 (테스트 타깃 말고 **앱 타깃**의 것):

```
				AB00000000000000000000B2 /* MenubKit */,
```

(d) PBXProject 객체(`C3F98F453006A06E00430473`)의 `projectRoot = "";` 다음 줄에:

```
			packageReferences = (
				AB00000000000000000000B1 /* XCLocalSwiftPackageReference "../Menub/MenubKit" */,
			);
```

(e) `/* Begin XCBuildConfiguration section */` 바로 **앞**에 삽입:

```
/* Begin XCLocalSwiftPackageReference section */
		AB00000000000000000000B1 /* XCLocalSwiftPackageReference "../Menub/MenubKit" */ = {
			isa = XCLocalSwiftPackageReference;
			relativePath = "../Menub/MenubKit";
		};
/* End XCLocalSwiftPackageReference section */

/* Begin XCSwiftPackageProductDependency section */
		AB00000000000000000000B2 /* MenubKit */ = {
			isa = XCSwiftPackageProductDependency;
			productName = MenubKit;
		};
/* End XCSwiftPackageProductDependency section */

```

- [ ] **Step 5: 빌드로 검증**

Run: `xcodebuild -project SkillBook.xcodeproj -scheme SkillBook -configuration Debug -derivedDataPath build build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **` (MenubKit 패키지 해석 포함)

Run: `plutil -p build/Build/Products/Debug/SkillBook.app/Contents/Info.plist | grep -E "LSUIElement|skillbook"`
Expected: `"LSUIElement" => 1` 와 `"skillbook"` 두 줄 다 출력

- [ ] **Step 6: 커밋**

```bash
git add .gitignore SkillBook/Info.plist SkillBook.xcodeproj/project.pbxproj
git commit -m "chore: 샌드박스 해제, LSUIElement·URL 스킴, MenubKit 로컬 패키지 연결"
```

---

### Task 2: Skill 모델 + frontmatter 파서

**Files:**
- Create: `SkillBook/Skill.swift`
- Create: `SkillBook/SkillScanner.swift`
- Create: `SkillBookTests/SkillScannerTests.swift` (기존 `SkillBookTests.swift`의 example 테스트는 이 태스크에서 삭제)
- Delete: `SkillBookTests/SkillBookTests.swift`

**Interfaces:**
- Consumes: 없음
- Produces:
  - `struct Skill: Identifiable, Equatable { let id: String; let name: String; let description: String; let categoryName: String; var invocation: String }`
  - `struct SkillCategory: Identifiable, Equatable { let name: String; let skills: [Skill]; var id: String }`
  - `SkillScanner.parseFrontmatter(_ text: String) -> (name: String?, description: String?)`

- [ ] **Step 1: 모델 작성** — `SkillBook/Skill.swift`

```swift
import Foundation

/// 설치된 스킬 하나. SKILL.md frontmatter에서 읽은 원문 그대로 담는다.
struct Skill: Identifiable, Equatable {
    /// SKILL.md 절대 경로 (고유 식별자)
    let id: String
    let name: String
    let description: String
    /// 소속 카테고리 (내 스킬 / 플러그인명)
    let categoryName: String

    /// 확정 발동용 슬래시 호출 텍스트. 예: "/git-flow"
    var invocation: String { "/\(name)" }
}

/// 치트시트 최상위 묶음: 내 스킬, 또는 플러그인 하나.
struct SkillCategory: Identifiable, Equatable {
    let name: String
    let skills: [Skill]

    var id: String { name }
}
```

- [ ] **Step 2: 실패하는 파서 테스트 작성** — `SkillBookTests/SkillScannerTests.swift` 생성, `SkillBookTests/SkillBookTests.swift` 삭제

```swift
import Testing
@testable import SkillBook

@MainActor
struct FrontmatterParserTests {

    @Test func 한줄_값_파싱() {
        let text = """
        ---
        name: git-flow
        description: 깃 작업 워크플로
        ---
        # 본문
        """
        let result = SkillScanner.parseFrontmatter(text)
        #expect(result.name == "git-flow")
        #expect(result.description == "깃 작업 워크플로")
    }

    @Test func 따옴표_값은_벗긴다() {
        let text = """
        ---
        name: brainstorming
        description: "You MUST use this before any creative work."
        ---
        """
        let result = SkillScanner.parseFrontmatter(text)
        #expect(result.description == "You MUST use this before any creative work.")
    }

    @Test func 접기_블록_여러줄은_공백으로_잇는다() {
        let text = """
        ---
        name: git-flow
        description: >-
          깃 작업을 정해진 5단계로,
          복사-붙여넣기 가능한 블록으로 전달하는 워크플로.
        ---
        """
        let result = SkillScanner.parseFrontmatter(text)
        #expect(result.description == "깃 작업을 정해진 5단계로, 복사-붙여넣기 가능한 블록으로 전달하는 워크플로.")
    }

    @Test func frontmatter_없으면_둘다_nil() {
        let result = SkillScanner.parseFrontmatter("# 그냥 마크다운\n본문")
        #expect(result.name == nil)
        #expect(result.description == nil)
    }

    @Test func 다른_키는_무시하고_필요한_키만_읽는다() {
        let text = """
        ---
        name: frontend-design
        license: Complete terms in LICENSE.txt
        description: Guidance for visual design.
        ---
        """
        let result = SkillScanner.parseFrontmatter(text)
        #expect(result.name == "frontend-design")
        #expect(result.description == "Guidance for visual design.")
    }
}
```

- [ ] **Step 3: 테스트 실패 확인**

Run: `xcodebuild test -project SkillBook.xcodeproj -scheme SkillBook -destination 'platform=macOS' -derivedDataPath build -only-testing:SkillBookTests 2>&1 | tail -10`
Expected: 컴파일 실패 — `cannot find 'SkillScanner' in scope`

- [ ] **Step 4: 파서 구현** — `SkillBook/SkillScanner.swift`

```swift
import Foundation

/// SKILL.md 파일과 설치 정보를 읽어 Skill 목록으로 바꾸는 순수 함수 모음.
/// 읽기 전용 — 어디에도 쓰지 않는다.
enum SkillScanner {

    /// SKILL.md 텍스트의 YAML frontmatter(--- 블록)에서 name/description만 추출한다.
    /// 지원 형태 (2026-07-15 설치본 44개 전수 조사 기준):
    /// - 한 줄 값: `key: 값` 또는 `key: "값"`
    /// - 접기 블록: `key: >-` 뒤 들여쓰기 줄들 → 공백으로 이어붙임
    static func parseFrontmatter(_ text: String) -> (name: String?, description: String?) {
        let lines = text.components(separatedBy: .newlines)
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else { return (nil, nil) }

        var name: String?
        var description: String?
        var index = 1
        while index < lines.count {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            if trimmed == "---" { break }
            if let raw = value(of: "name", in: trimmed) {
                name = foldIfNeeded(raw, lines: lines, index: &index)
            } else if let raw = value(of: "description", in: trimmed) {
                description = foldIfNeeded(raw, lines: lines, index: &index)
            }
            index += 1
        }
        return (name, description)
    }

    /// `key: 값` 형태의 줄에서 값을 꺼낸다. 키가 다르면 nil.
    private static func value(of key: String, in trimmedLine: String) -> String? {
        guard trimmedLine.hasPrefix("\(key):") else { return nil }
        return String(trimmedLine.dropFirst(key.count + 1)).trimmingCharacters(in: .whitespaces)
    }

    private static let blockMarkers: Set<String> = [">", ">-", "|", "|-"]

    /// 값이 YAML 블록 마커면 이어지는 들여쓰기 줄들을 공백으로 이어붙인다.
    /// 일반 값이면 양끝 따옴표만 벗긴다. index는 소비한 줄만큼 전진시킨다.
    private static func foldIfNeeded(_ raw: String, lines: [String], index: inout Int) -> String {
        guard blockMarkers.contains(raw) else { return unquote(raw) }
        var parts: [String] = []
        var next = index + 1
        while next < lines.count {
            let line = lines[next]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // 블록은 비어 있지 않은 들여쓰기 줄이 이어지는 동안 계속된다.
            guard !trimmed.isEmpty, line.hasPrefix(" ") || line.hasPrefix("\t") else { break }
            parts.append(trimmed)
            next += 1
        }
        index = next - 1
        return parts.joined(separator: " ")
    }

    private static func unquote(_ value: String) -> String {
        guard value.count >= 2, value.hasPrefix("\""), value.hasSuffix("\"") else { return value }
        return String(value.dropFirst().dropLast())
    }
}
```

- [ ] **Step 5: 테스트 통과 확인**

Run: `xcodebuild test -project SkillBook.xcodeproj -scheme SkillBook -destination 'platform=macOS' -derivedDataPath build -only-testing:SkillBookTests 2>&1 | tail -5`
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 6: 커밋**

```bash
git add SkillBook/Skill.swift SkillBook/SkillScanner.swift SkillBookTests/
git commit -m "feat: Skill 모델과 frontmatter 파서 (한 줄 값·따옴표·접기 블록 지원)"
```

---

### Task 3: 폴더 스캐너 + installed_plugins.json 파서

**Files:**
- Modify: `SkillBook/SkillScanner.swift` (함수 추가)
- Modify: `SkillBookTests/SkillScannerTests.swift` (테스트 struct 추가)

**Interfaces:**
- Consumes: Task 2의 `Skill`, `SkillScanner.parseFrontmatter`
- Produces:
  - `SkillScanner.scanSkillsDirectory(_ directory: URL, categoryName: String) -> [Skill]` — 하위 폴더의 SKILL.md들을 이름순으로 파싱. name 누락 → 폴더명, description 누락 → "(설명 없음)".
  - `SkillScanner.pluginInstallPaths(fromJSON data: Data) -> [(name: String, installPath: URL)]` — `이름@마켓` 키에서 이름만 취해 알파벳순 정렬.

- [ ] **Step 1: 실패하는 테스트 추가** — `SkillBookTests/SkillScannerTests.swift` 끝에 추가

```swift
import Foundation

@MainActor
struct SkillDirectoryScanTests {

    /// 테스트용 임시 디렉토리를 만들고 경로를 돌려준다.
    private func makeTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("SkillBookTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func writeSkill(in base: URL, folder: String, contents: String?) throws {
        let dir = base.appendingPathComponent(folder, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let contents {
            try contents.write(to: dir.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)
        }
    }

    @Test func 하위폴더의_SKILL_md를_이름순으로_읽는다() throws {
        let base = try makeTempDirectory()
        try writeSkill(in: base, folder: "b-skill", contents: "---\nname: b-skill\ndescription: 비\n---\n")
        try writeSkill(in: base, folder: "a-skill", contents: "---\nname: a-skill\ndescription: 에이\n---\n")

        let skills = SkillScanner.scanSkillsDirectory(base, categoryName: "내 스킬")

        #expect(skills.map(\.name) == ["a-skill", "b-skill"])
        #expect(skills.allSatisfy { $0.categoryName == "내 스킬" })
        #expect(skills[0].invocation == "/a-skill")
    }

    @Test func SKILL_md_없는_폴더는_건너뛴다() throws {
        let base = try makeTempDirectory()
        try writeSkill(in: base, folder: "empty-folder", contents: nil)
        try writeSkill(in: base, folder: "real", contents: "---\nname: real\ndescription: 진짜\n---\n")

        let skills = SkillScanner.scanSkillsDirectory(base, categoryName: "내 스킬")
        #expect(skills.map(\.name) == ["real"])
    }

    @Test func name_누락은_폴더명_description_누락은_설명없음() throws {
        let base = try makeTempDirectory()
        try writeSkill(in: base, folder: "no-front", contents: "# frontmatter 없음\n")

        let skills = SkillScanner.scanSkillsDirectory(base, categoryName: "내 스킬")
        #expect(skills.count == 1)
        #expect(skills[0].name == "no-front")
        #expect(skills[0].description == "(설명 없음)")
    }

    @Test func 없는_디렉토리는_빈_배열() {
        let missing = URL(fileURLWithPath: "/nonexistent/skills")
        #expect(SkillScanner.scanSkillsDirectory(missing, categoryName: "내 스킬").isEmpty)
    }
}

@MainActor
struct PluginInstallPathTests {

    @Test func 설치_플러그인의_이름과_경로를_알파벳순으로_읽는다() throws {
        let json = """
        {
          "version": 2,
          "plugins": {
            "superpowers@claude-plugins-official": [
              { "scope": "user", "installPath": "/tmp/cache/superpowers/6.1.1", "version": "6.1.1" }
            ],
            "code-review@claude-plugins-official": [
              { "scope": "user", "installPath": "/tmp/cache/code-review/unknown", "version": "unknown" }
            ]
          }
        }
        """
        let result = SkillScanner.pluginInstallPaths(fromJSON: Data(json.utf8))

        // 튜플은 key path를 지원하지 않으므로 클로저로 꺼낸다
        #expect(result.map { $0.name } == ["code-review", "superpowers"])
        #expect(result[1].installPath.path == "/tmp/cache/superpowers/6.1.1")
    }

    @Test func 깨진_JSON은_빈_배열() {
        #expect(SkillScanner.pluginInstallPaths(fromJSON: Data("not json".utf8)).isEmpty)
    }
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `xcodebuild test -project SkillBook.xcodeproj -scheme SkillBook -destination 'platform=macOS' -derivedDataPath build -only-testing:SkillBookTests 2>&1 | tail -10`
Expected: 컴파일 실패 — `type 'SkillScanner' has no member 'scanSkillsDirectory'`

- [ ] **Step 3: 구현** — `SkillBook/SkillScanner.swift`의 `parseFrontmatter` 위(enum 본문 안 맨 앞)에 추가

```swift
    /// 디렉토리의 하위 폴더들에서 SKILL.md를 찾아 파싱한다. 폴더 이름순 정렬.
    /// SKILL.md가 없거나 읽을 수 없는 폴더는 조용히 건너뛴다 (관대한 에러 처리).
    static func scanSkillsDirectory(_ directory: URL, categoryName: String) -> [Skill] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
        ) else { return [] }

        var skills: [Skill] = []
        for entry in entries.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let skillFile = entry.appendingPathComponent("SKILL.md")
            guard let text = try? String(contentsOf: skillFile, encoding: .utf8) else { continue }
            let parsed = parseFrontmatter(text)
            skills.append(Skill(
                id: skillFile.path,
                name: parsed.name ?? entry.lastPathComponent,
                description: parsed.description ?? "(설명 없음)",
                categoryName: categoryName
            ))
        }
        return skills
    }

    /// installed_plugins.json에서 (플러그인 이름, 설치 경로) 목록을 읽는다.
    /// 키는 `이름@마켓플레이스` 형태 — 이름만 취한다. 알파벳순 정렬.
    /// 파싱 실패 시 빈 배열 (개인 스킬만 표시하는 것으로 축퇴).
    static func pluginInstallPaths(fromJSON data: Data) -> [(name: String, installPath: URL)] {
        struct PluginEntry: Decodable { let installPath: String }
        struct InstalledPlugins: Decodable { let plugins: [String: [PluginEntry]] }

        guard let decoded = try? JSONDecoder().decode(InstalledPlugins.self, from: data) else { return [] }
        return decoded.plugins
            .compactMap { key, entries -> (name: String, installPath: URL)? in
                guard let entry = entries.first else { return nil }
                let name = key.split(separator: "@").first.map(String.init) ?? key
                return (name, URL(fileURLWithPath: entry.installPath, isDirectory: true))
            }
            .sorted { $0.name < $1.name }
    }
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `xcodebuild test -project SkillBook.xcodeproj -scheme SkillBook -destination 'platform=macOS' -derivedDataPath build -only-testing:SkillBookTests 2>&1 | tail -5`
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: 커밋**

```bash
git add SkillBook/SkillScanner.swift SkillBookTests/SkillScannerTests.swift
git commit -m "feat: 스킬 폴더 스캐너와 installed_plugins.json 파서"
```

---

### Task 4: SkillStore

**Files:**
- Create: `SkillBook/SkillStore.swift`
- Modify: `SkillBookTests/SkillScannerTests.swift` (테스트 struct 추가)

**Interfaces:**
- Consumes: Task 2·3의 `Skill`, `SkillCategory`, `SkillScanner` 전부
- Produces:
  - `final class SkillStore: ObservableObject` — `@Published private(set) var categories: [SkillCategory]`
  - `SkillStore.personalCategoryName == "내 스킬"` (static let)
  - `init(claudeDirectory: URL = ~/.claude)` / `func reload()`

- [ ] **Step 1: 실패하는 테스트 추가** — `SkillBookTests/SkillScannerTests.swift` 끝에 추가

```swift
@MainActor
struct SkillStoreTests {

    /// 가짜 ~/.claude 구조를 임시 폴더에 만든다.
    private func makeFakeClaudeDirectory() throws -> URL {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("SkillBookStoreTests-\(UUID().uuidString)", isDirectory: true)
        let fm = FileManager.default

        // 개인 스킬 1개
        let personal = base.appendingPathComponent("skills/my-skill", isDirectory: true)
        try fm.createDirectory(at: personal, withIntermediateDirectories: true)
        try "---\nname: my-skill\ndescription: 내 것\n---\n"
            .write(to: personal.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)

        // 플러그인: alpha는 스킬 1개, beta는 skills 폴더 없음(카테고리 생략돼야 함)
        let alphaSkill = base.appendingPathComponent("cache/alpha/1.0/skills/alpha-skill", isDirectory: true)
        try fm.createDirectory(at: alphaSkill, withIntermediateDirectories: true)
        try "---\nname: alpha-skill\ndescription: 알파\n---\n"
            .write(to: alphaSkill.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)
        let betaDir = base.appendingPathComponent("cache/beta/1.0", isDirectory: true)
        try fm.createDirectory(at: betaDir, withIntermediateDirectories: true)

        let pluginsDir = base.appendingPathComponent("plugins", isDirectory: true)
        try fm.createDirectory(at: pluginsDir, withIntermediateDirectories: true)
        let json = """
        {
          "version": 2,
          "plugins": {
            "alpha@market": [ { "installPath": "\(base.path)/cache/alpha/1.0" } ],
            "beta@market": [ { "installPath": "\(base.path)/cache/beta/1.0" } ]
          }
        }
        """
        try json.write(to: pluginsDir.appendingPathComponent("installed_plugins.json"),
                       atomically: true, encoding: .utf8)
        return base
    }

    @Test func 내스킬이_먼저_그다음_플러그인_빈_플러그인은_생략() throws {
        let claudeDir = try makeFakeClaudeDirectory()
        let store = SkillStore(claudeDirectory: claudeDir)

        #expect(store.categories.map(\.name) == ["내 스킬", "alpha"])
        #expect(store.categories[0].skills.map(\.name) == ["my-skill"])
        #expect(store.categories[1].skills.map(\.name) == ["alpha-skill"])
    }

    @Test func 아무것도_없으면_카테고리_빈_배열() {
        let store = SkillStore(claudeDirectory: URL(fileURLWithPath: "/nonexistent/.claude"))
        #expect(store.categories.isEmpty)
    }
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `xcodebuild test -project SkillBook.xcodeproj -scheme SkillBook -destination 'platform=macOS' -derivedDataPath build -only-testing:SkillBookTests 2>&1 | tail -10`
Expected: 컴파일 실패 — `cannot find 'SkillStore' in scope`

- [ ] **Step 3: 구현** — `SkillBook/SkillStore.swift`

```swift
import Foundation
import Combine

/// 설치된 스킬을 읽어 카테고리 목록으로 제공하는 읽기 전용 저장소.
/// 순서: "내 스킬" 먼저, 그다음 플러그인 알파벳순. 스킬이 없는 카테고리는 생략.
final class SkillStore: ObservableObject {
    @Published private(set) var categories: [SkillCategory] = []

    static let personalCategoryName = "내 스킬"

    private let claudeDirectory: URL

    init(claudeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude", isDirectory: true)) {
        self.claudeDirectory = claudeDirectory
        reload()
    }

    /// 디스크를 다시 스캔한다. 앱 실행·패널 표시·수동 새로고침 시 호출.
    func reload() {
        var result: [SkillCategory] = []

        let personal = SkillScanner.scanSkillsDirectory(
            claudeDirectory.appendingPathComponent("skills", isDirectory: true),
            categoryName: Self.personalCategoryName
        )
        if !personal.isEmpty {
            result.append(SkillCategory(name: Self.personalCategoryName, skills: personal))
        }

        let jsonURL = claudeDirectory.appendingPathComponent("plugins/installed_plugins.json")
        if let data = try? Data(contentsOf: jsonURL) {
            for plugin in SkillScanner.pluginInstallPaths(fromJSON: data) {
                let skills = SkillScanner.scanSkillsDirectory(
                    plugin.installPath.appendingPathComponent("skills", isDirectory: true),
                    categoryName: plugin.name
                )
                if !skills.isEmpty {
                    result.append(SkillCategory(name: plugin.name, skills: skills))
                }
            }
        }

        categories = result
    }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `xcodebuild test -project SkillBook.xcodeproj -scheme SkillBook -destination 'platform=macOS' -derivedDataPath build -only-testing:SkillBookTests 2>&1 | tail -5`
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: 커밋**

```bash
git add SkillBook/SkillStore.swift SkillBookTests/SkillScannerTests.swift
git commit -m "feat: SkillStore — 내 스킬 + 플러그인 카테고리 조립"
```

---

### Task 5: MacKey 이식 — PanelController · AppDetector

**Files:**
- Create: `SkillBook/PanelController.swift` (MacKey에서 복사 후 수정)
- Create: `SkillBook/AppDetector.swift` (MacKey에서 그대로 복사)

**Interfaces:**
- Consumes: Task 4의 `SkillStore`. **주의:** 이 태스크가 참조하는 `SkillListView`는 Task 6에서 만들어지므로, 이 태스크의 빌드 확인은 Task 6과 묶어서 한다 (이 태스크에서는 파일 생성과 수정만 하고 커밋은 Task 6에서 함께).
- Produces:
  - `final class PanelController { init(store: SkillStore); func show(); func hide(); static let panelWidth: CGFloat }` — `show()`는 패널 생성/표시만, reload는 호출자 책임.
  - `final class AppDetector { var onChange: ((Bool) -> Void)?; func start(); func stop() }`
  - `final class FloatingPanel: NSPanel` (PanelController.swift 안)

- [ ] **Step 1: 두 파일 복사**

```bash
cp /Users/seokho/Developer/MacKey/Sources/MacKey/PanelController.swift SkillBook/PanelController.swift
cp /Users/seokho/Developer/MacKey/Sources/MacKey/AppDetector.swift SkillBook/AppDetector.swift
```

- [ ] **Step 2: PanelController.swift 수정 (4곳)**

(a) store 타입과 init — openSettings 제거:

```swift
    private var panel: FloatingPanel?
    private let store: ShortcutStore
    private let openSettings: () -> Void
```
→
```swift
    private var panel: FloatingPanel?
    private let store: SkillStore
```

```swift
    init(store: ShortcutStore, openSettings: @escaping () -> Void) {
        self.store = store
        self.openSettings = openSettings
    }
```
→
```swift
    init(store: SkillStore) {
        self.store = store
    }
```

(b) UserDefaults 키:

```swift
    private let frameKey = "MacKey.panelTopOrigin"
```
→
```swift
    private let frameKey = "SkillBook.panelTopOrigin"
```

(c) buildPanel의 루트 뷰 (`let root = ShortcutListView(` 부터 닫는 괄호까지 교체):

```swift
        let root = ShortcutListView(
            store: store,
            onHeightChange: { [weak self] height, hasExpanded in
                // SwiftUI 레이아웃 도중 윈도우 리사이즈가 일어나지 않도록 다음 런루프로 미룸
                DispatchQueue.main.async { self?.adjustHeight(to: height, hasExpanded: hasExpanded) }
            },
            onSettings: { [weak self] in
                self?.openSettings()
            }
        )
```
→
```swift
        let root = SkillListView(
            store: store,
            onHeightChange: { [weak self] height, hasExpanded in
                // SwiftUI 레이아웃 도중 윈도우 리사이즈가 일어나지 않도록 다음 런루프로 미룸
                DispatchQueue.main.async { self?.adjustHeight(to: height, hasExpanded: hasExpanded) }
            },
            onRefresh: { [weak self] in self?.store.reload() }
        )
```

(d) 디버그 로그 태그:

```swift
        print("[MacKey] contentHeight: \(contentHeight), expanded: \(hasExpanded), panel: \(panel.frame.size)")
```
→
```swift
        print("[SkillBook] contentHeight: \(contentHeight), expanded: \(hasExpanded), panel: \(panel.frame.size)")
```

- [ ] **Step 3: AppDetector.swift는 무수정 확인** (Claude 데스크톱 감지 로직 동일. diff로 확인만)

Run: `diff /Users/seokho/Developer/MacKey/Sources/MacKey/AppDetector.swift SkillBook/AppDetector.swift && echo SAME`
Expected: `SAME`

(빌드·커밋은 Task 6에서 SkillListView와 함께.)

---

### Task 6: SkillListView — 카테고리 ▸ 스킬 ▸ 설명 3단 UI

**Files:**
- Create: `SkillBook/SkillListView.swift`
- Test: 빌드 성공 + Task 5 파일 포함 커밋 (UI 자체는 Task 8에서 수동 검증)

**Interfaces:**
- Consumes: `SkillStore`(Task 4), `PanelController.panelWidth`(Task 5)
- Produces: `struct SkillListView: View` — `init(store: SkillStore, onHeightChange: @escaping (CGFloat, Bool) -> Void, onRefresh: @escaping () -> Void)`. `onHeightChange`의 Bool은 "펼쳐진 **스킬**(설명)이 있는가" — 카테고리 펼침은 기본 높이(내부 스크롤)에 포함시켜 PanelController를 무수정으로 재활용한다.

- [ ] **Step 1: 뷰 작성** — `SkillBook/SkillListView.swift`

```swift
import SwiftUI
import AppKit

/// 스티키노트 본체: 카테고리 ▸ 스킬 ▸ 설명 3단계 목록.
struct SkillListView: View {
    @ObservedObject var store: SkillStore
    /// (콘텐츠 높이, 펼쳐진 스킬 존재 여부)
    var onHeightChange: (CGFloat, Bool) -> Void
    var onRefresh: () -> Void

    /// 펼쳐진 카테고리 이름들. UserDefaults에 유지, 첫 실행은 "내 스킬"만.
    @State private var expandedCategories: Set<String>
    /// 펼쳐진 스킬 id들 (앱 세션 한정).
    @State private var expandedSkillIDs: Set<String> = []
    @State private var headerHeight: CGFloat = 0
    @State private var listHeight: CGFloat = 0

    private static let expandedCategoriesKey = "SkillBook.expandedCategories"

    init(store: SkillStore,
         onHeightChange: @escaping (CGFloat, Bool) -> Void,
         onRefresh: @escaping () -> Void) {
        self.store = store
        self.onHeightChange = onHeightChange
        self.onRefresh = onRefresh
        let saved = UserDefaults.standard.stringArray(forKey: Self.expandedCategoriesKey)
        _expandedCategories = State(initialValue: Set(saved ?? [SkillStore.personalCategoryName]))
    }

    var body: some View {
        VStack(spacing: 0) {
            // 상단 바는 스크롤 밖에 고정
            VStack(spacing: 0) {
                header
                Divider().opacity(0.4)
            }
            .reportHeight(into: $headerHeight)

            ScrollView(showsIndicators: false) {
                Group {
                    if store.categories.isEmpty {
                        emptyState
                    } else {
                        list
                    }
                }
                .reportHeight(into: $listHeight)
            }
        }
        .onChange(of: headerHeight) { _, _ in report() }
        .onChange(of: listHeight) { _, _ in report() }
        // 새로고침으로 목록 자체가 바뀌면 다음 런루프에 높이를 다시 보고
        .onChange(of: store.categories) { _, _ in
            DispatchQueue.main.async { report() }
        }
        .onChange(of: expandedCategories) { _, newValue in
            UserDefaults.standard.set(Array(newValue).sorted(), forKey: Self.expandedCategoriesKey)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.97))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .frame(width: PanelController.panelWidth)
    }

    /// 전체 콘텐츠 높이(고정 상단 바 + 리스트)를 컨트롤러에 전달
    private func report() {
        onHeightChange(headerHeight + listHeight, !expandedSkillIDs.isEmpty)
    }

    // MARK: - 상단 바

    private var header: some View {
        HStack {
            Text("스킬")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("새로고침")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - 리스트

    private var list: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(store.categories) { category in
                CategoryRow(
                    category: category,
                    isExpanded: expandedCategories.contains(category.name),
                    toggle: {
                        withAnimation(.easeOut(duration: 0.18)) {
                            if expandedCategories.contains(category.name) {
                                expandedCategories.remove(category.name)
                            } else {
                                expandedCategories.insert(category.name)
                            }
                        }
                    }
                )
                if expandedCategories.contains(category.name) {
                    ForEach(category.skills) { skill in
                        SkillRow(
                            skill: skill,
                            isExpanded: expandedSkillIDs.contains(skill.id),
                            toggle: {
                                withAnimation(.easeOut(duration: 0.18)) {
                                    if expandedSkillIDs.contains(skill.id) {
                                        expandedSkillIDs.remove(skill.id)
                                    } else {
                                        expandedSkillIDs.insert(skill.id)
                                    }
                                }
                            }
                        )
                    }
                }
                if category.id != store.categories.last?.id {
                    Divider().opacity(0.25).padding(.leading, 12)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var emptyState: some View {
        Text("설치된 스킬이 없습니다.\n~/.claude/skills/ 를 확인하세요")
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
    }
}

/// 카테고리 행: 클릭하면 접기/펼치기. 스킬 개수 뱃지 표시.
private struct CategoryRow: View {
    let category: SkillCategory
    let isExpanded: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .frame(width: 18, height: 18)
                Text(category.name)
                    .font(.system(size: 12.5, weight: .semibold))
                Text("(\(category.skills.count))")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }
}

/// 스킬 한 줄 + 설명 토글. 이름 클릭 = /이름 복사.
private struct SkillRow: View {
    let skill: Skill
    let isExpanded: Bool
    let toggle: () -> Void

    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                // > 클릭: 설명 펼침/접힘
                Button(action: toggle) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .frame(width: 18, height: 18)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("설명 펼치기/접기")

                // 이름 클릭: /이름 형식으로 클립보드 복사
                Button(action: copy) {
                    HStack(spacing: 4) {
                        Text(skill.name)
                            .font(.system(size: 12.5, weight: .medium))
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        if copied {
                            Text("복사됨")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                .transition(.opacity)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("\(skill.invocation) 복사")
            }
            .padding(.leading, 24)
            .padding(.trailing, 12)
            .padding(.vertical, 6)

            if isExpanded {
                Text(skill.description)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 42)
                    .padding(.trailing, 12)
                    .padding(.bottom, 8)
            }
        }
    }

    private func copy() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(skill.invocation, forType: .string)
        withAnimation(.easeOut(duration: 0.15)) { copied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.3)) { copied = false }
        }
    }
}

// MARK: - 높이 측정

/// 콘텐츠의 실제 높이를 배경 GeometryReader로 읽어 바인딩에 기록하는 모디파이어.
/// preference는 macOS ScrollView 경계를 넘어 전파되지 않는 경우가 있어
/// GeometryReader에서 상태에 직접 기록한다.
private struct HeightReportingModifier: ViewModifier {
    @Binding var height: CGFloat

    func body(content: Content) -> some View {
        content.background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear { height = proxy.size.height }
                    .onChange(of: proxy.size.height) { _, newValue in height = newValue }
            }
        )
    }
}

private extension View {
    /// 이 뷰의 높이를 측정해 주어진 바인딩에 기록한다.
    func reportHeight(into height: Binding<CGFloat>) -> some View {
        modifier(HeightReportingModifier(height: height))
    }
}
```

- [ ] **Step 2: 빌드 확인** (Task 5의 두 파일 포함)

Run: `xcodebuild -project SkillBook.xcodeproj -scheme SkillBook -configuration Debug -derivedDataPath build build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: 기존 테스트 여전히 통과 확인**

Run: `xcodebuild test -project SkillBook.xcodeproj -scheme SkillBook -destination 'platform=macOS' -derivedDataPath build -only-testing:SkillBookTests 2>&1 | tail -5`
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 4: 커밋** (Task 5 + 6 함께)

```bash
git add SkillBook/PanelController.swift SkillBook/AppDetector.swift SkillBook/SkillListView.swift
git commit -m "feat: MacKey 패널·감지기 이식 + 카테고리 3단 스킬 리스트 뷰"
```

---

### Task 7: 앱 조립 — AppDelegate · 메뉴 · menub 통합 · 템플릿 제거

**Files:**
- Create: `SkillBook/SkillBookMenub.swift`
- Modify: `SkillBook/SkillBookApp.swift` (전체 교체)
- Delete: `SkillBook/ContentView.swift`

**Interfaces:**
- Consumes: `SkillStore`, `PanelController`, `AppDetector`, `SkillListView`, MenubKit(`MenubSatellite`)
- Produces: 실행 가능한 완성 앱. `SkillBookMenub.configure(showPanel:openSkillsFolder:)`, `.route(_ url:)`, `.shouldCreateStatusItem`.

- [ ] **Step 1: menub 통합 작성** — `SkillBook/SkillBookMenub.swift` (MacKey의 MenubIntegration와 같은 3계약)

```swift
//
//  SkillBookMenub.swift
//  SkillBook ↔ menub 허브 통합. 3계약:
//   1) 정적 액션(패널·폴더)을 매니페스트로 기록
//   2) URL(skillbook://action/<id>) 수신 시 해당 동작 실행
//   3) 허브가 관리 중이면 상태 아이템을 만들지 않음
//

import AppKit
import Foundation
import MenubKit

final class SkillBookMenub {
    let satellite = MenubSatellite(
        id: "skillbook",
        displayName: "SkillBook",
        urlScheme: "skillbook",
        bundleIdentifier: Bundle.main.bundleIdentifier,
        iconRef: "sf:books.vertical"
    )

    /// 매니페스트 기록 + 라우팅 핸들러 연결. (앱 실행 시 1회)
    func configure(showPanel: @escaping () -> Void, openSkillsFolder: @escaping () -> Void) {
        satellite.setActions([
            satellite.makeAction(id: "panel", title: "스킬 패널 보기", iconRef: "sf:books.vertical"),
            satellite.makeAction(id: "folder", title: "스킬 폴더 열기", iconRef: "sf:folder")
        ])
        satellite.setQuitAction { NSApplication.shared.terminate(nil) }   // 허브에서 종료
        _ = satellite.writeManifest()   // 계약 1

        satellite.onInvoke { actionID in   // 계약 2
            switch actionID {
            case "panel":  showPanel()
            case "folder": openSkillsFolder()
            default:       break
            }
        }
    }

    func route(_ url: URL) {
        _ = satellite.route(url)
    }

    /// 계약 3: 상태 아이템을 만들어야 하는가(허브가 관리하지 않는가).
    var shouldCreateStatusItem: Bool {
        satellite.shouldCreateStatusItem()
    }
}
```

- [ ] **Step 2: 앱 진입점 교체** — `SkillBook/SkillBookApp.swift` 전체를 아래로 교체, `SkillBook/ContentView.swift` 삭제

```swift
import AppKit
import SwiftUI

@main
struct SkillBookApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        // 메인 윈도우 없는 메뉴바 앱 — Settings 씬은 빈 껍데기
        Settings { EmptyView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = SkillStore()
    private let detector = AppDetector()
    private let menub = SkillBookMenub()
    private var panelController: PanelController!
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // Dock 아이콘 없는 메뉴바 앱

        panelController = PanelController(store: store)

        // menub 통합: 매니페스트 기록 + 라우팅 연결 (계약 1·2)
        menub.configure(
            showPanel: { [weak self] in self?.showPanel() },
            openSkillsFolder: { Self.openSkillsFolder() }
        )

        // 계약 3: 허브가 관리 중이면 자기 상태 아이템을 만들지 않는다(실행 시 결정).
        if menub.shouldCreateStatusItem {
            setupStatusItem()
        }

        detector.onChange = { [weak self] shouldShow in
            if shouldShow {
                self?.showPanel()
            } else {
                self?.panelController.hide()
            }
        }
        detector.start()
    }

    // 계약 2: skillbook://action/<id> 수신 → 해당 동작 실행
    func application(_ application: NSApplication, open urls: [URL]) {
        urls.forEach { menub.route($0) }
    }

    /// 패널 표시 직전에 항상 디스크를 다시 스캔한다 (스펙: 표시 시마다 reload).
    private func showPanel() {
        store.reload()
        panelController.show()
    }

    private static func openSkillsFolder() {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/skills", isDirectory: true)
        NSWorkspace.shared.open(url)
    }

    // MARK: - 메뉴바

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "books.vertical",
                accessibilityDescription: "SkillBook"
            )
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "스킬 패널 보기", action: #selector(showPanelAction), keyEquivalent: "p"))
        menu.addItem(NSMenuItem(title: "스킬 폴더 열기", action: #selector(openFolderAction), keyEquivalent: "o"))
        menu.addItem(NSMenuItem(title: "새로고침", action: #selector(refreshAction), keyEquivalent: "r"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "SkillBook 종료", action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        statusItem.menu = menu
    }

    @objc private func showPanelAction() { showPanel() }
    @objc private func openFolderAction() { Self.openSkillsFolder() }
    @objc private func refreshAction() { store.reload() }
    @objc private func quit() { NSApp.terminate(nil) }
}
```

- [ ] **Step 3: 빌드 + 테스트 확인**

Run: `xcodebuild -project SkillBook.xcodeproj -scheme SkillBook -configuration Debug -derivedDataPath build build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

Run: `xcodebuild test -project SkillBook.xcodeproj -scheme SkillBook -destination 'platform=macOS' -derivedDataPath build -only-testing:SkillBookTests 2>&1 | tail -5`
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 4: 커밋**

```bash
git add SkillBook/SkillBookMenub.swift SkillBook/SkillBookApp.swift
git rm SkillBook/ContentView.swift
git commit -m "feat: 앱 조립 — AppDelegate·메뉴바·menub 통합, 템플릿 제거"
```

---

### Task 8: 전체 검증 (테스트 스위트 + 실행 + 수동 체크리스트)

**Files:**
- 없음 (검증만)

**Interfaces:**
- Consumes: 완성된 앱 전체
- Produces: 검증 결과 보고

- [ ] **Step 1: 전체 단위 테스트**

Run: `xcodebuild test -project SkillBook.xcodeproj -scheme SkillBook -destination 'platform=macOS' -derivedDataPath build -only-testing:SkillBookTests 2>&1 | tail -5`
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 2: 앱 실행**

Run: `open build/Build/Products/Debug/SkillBook.app`
Expected: 메뉴바에 books.vertical 아이콘 등장 (Dock 아이콘 없음)

- [ ] **Step 3: 실데이터 스모크 테스트** — 앱이 읽을 실제 데이터를 CLI로 교차 확인

Run: `ls ~/.claude/skills/ && python3 -c "import json;d=json.load(open('$HOME/.claude/plugins/installed_plugins.json'));print(sorted(k.split('@')[0] for k in d['plugins']))"`
Expected: 개인 스킬 4개 폴더 + 플러그인 이름 목록 → 패널 표시 내용과 일치해야 함

- [ ] **Step 4: 수동 체크리스트를 사용자에게 제시하고 확인 요청**

사용자가 직접 확인할 항목:
1. Claude 데스크톱 앱을 앞으로 → 패널 자동 표시, 다른 앱으로 전환 → 숨김
2. 첫 실행 시 "내 스킬"만 펼쳐져 있고 4개 표시, superpowers·frontend-design 카테고리가 개수 뱃지와 함께 접혀 있음 (code-review·security-guidance는 SKILL.md가 없어 안 보이는 게 정상)
3. 카테고리 클릭 → 접기/펼치기, 앱 재시작 후에도 상태 유지
4. 스킬 이름 클릭 → "복사됨" 표시, 붙여넣으면 `/git-flow` 형식
5. 스킬 화살표 클릭 → description 원문 표시
6. 메뉴바 아이콘: 패널 보기 / 스킬 폴더 열기 / 새로고침 / 종료 동작
7. 터미널에서 `open "skillbook://action/panel"` → 패널 표시 (URL 라우팅)

- [ ] **Step 5: 사용자 확인 후 완료 처리** — superpowers:finishing-a-development-branch 스킬로 마무리
