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
