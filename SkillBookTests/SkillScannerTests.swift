import Foundation
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
