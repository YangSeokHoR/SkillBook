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
