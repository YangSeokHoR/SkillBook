import Foundation
import Combine

/// 설치된 스킬을 읽어 카테고리 목록으로 제공하는 읽기 전용 저장소.
/// 순서: "내 스킬" 먼저, 그다음 플러그인 알파벳순. 스킬이 없는 카테고리는 생략.
final class SkillStore: ObservableObject {
    @Published private(set) var categories: [SkillCategory] = []

    static let personalCategoryName = "내 스킬"
    /// 스킬이 하나뿐인 플러그인들을 모아두는 카테고리 (뎁스 낭비 방지). 항상 맨 뒤.
    static let singlePluginCategoryName = "단일플러그인"

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
        var singles: [Skill] = []
        if let data = try? Data(contentsOf: jsonURL) {
            for plugin in SkillScanner.pluginInstallPaths(fromJSON: data) {
                let skills = SkillScanner.scanSkillsDirectory(
                    plugin.installPath.appendingPathComponent("skills", isDirectory: true),
                    categoryName: plugin.name
                )
                if skills.count == 1 {
                    singles.append(contentsOf: skills)
                } else if !skills.isEmpty {
                    result.append(SkillCategory(name: plugin.name, skills: skills))
                }
            }
        }
        if !singles.isEmpty {
            result.append(SkillCategory(name: Self.singlePluginCategoryName, skills: singles))
        }

        categories = applyTranslations(to: result)
    }

    /// 번역 오버라이드 적용. `<claudeDirectory>/skillbook-ko.json`(스킬 이름 → 한국어 설명)이
    /// 있으면 매칭되는 스킬의 설명만 교체한다. 파일이 없거나 깨졌으면 원문 그대로.
    private func applyTranslations(to categories: [SkillCategory]) -> [SkillCategory] {
        let url = claudeDirectory.appendingPathComponent("skillbook-ko.json")
        guard let data = try? Data(contentsOf: url),
              let translations = try? JSONDecoder().decode([String: String].self, from: data)
        else { return categories }

        return categories.map { category in
            SkillCategory(name: category.name, skills: category.skills.map { skill in
                guard let translated = translations[skill.name] else { return skill }
                return Skill(id: skill.id, name: skill.name,
                             description: translated, categoryName: skill.categoryName)
            })
        }
    }
}
