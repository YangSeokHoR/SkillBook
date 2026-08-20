import Foundation
import Combine

/// 설치된 스킬을 읽어 카테고리 목록으로 제공하는 읽기 전용 저장소.
/// 순서: "내 스킬" → "단일플러그인" → 다중 스킬 플러그인 알파벳순. 스킬이 없는 카테고리는 생략.
final class SkillStore: ObservableObject {
    @Published private(set) var categories: [SkillCategory] = []

    static let personalCategoryName = "내 스킬"
    /// 스킬이 하나뿐인 플러그인들을 모아두는 카테고리 (뎁스 낭비 방지). "내 스킬" 바로 다음.
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
            claudeDirectory.appendingPathComponent("skills", isDirectory: true)
        )
        let groups = declaredGroups()
        let mine = personal.filter { groups[$0.name] == nil }
        if !mine.isEmpty {
            result.append(SkillCategory(name: Self.personalCategoryName, skills: mine))
        }
        // 선언된 그룹은 플러그인과 같은 층위로 취급해 뒤에서 알파벳순으로 함께 정렬한다.
        var declared: [SkillCategory] = Dictionary(grouping: personal.filter { groups[$0.name] != nil },
                                                   by: { groups[$0.name]! })
            .map { SkillCategory(name: $0.key, skills: $0.value) }

        let jsonURL = claudeDirectory.appendingPathComponent("plugins/installed_plugins.json")
        var singles: [Skill] = []
        var multiSkillPlugins: [SkillCategory] = []
        if let data = try? Data(contentsOf: jsonURL) {
            for plugin in SkillScanner.pluginInstallPaths(fromJSON: data) {
                let skills = SkillScanner.scanSkillsDirectory(
                    plugin.installPath.appendingPathComponent("skills", isDirectory: true)
                )
                if skills.count == 1 {
                    singles.append(contentsOf: skills)
                } else if !skills.isEmpty {
                    multiSkillPlugins.append(SkillCategory(name: plugin.name, skills: skills))
                }
            }
        }
        if !singles.isEmpty {
            result.append(SkillCategory(name: Self.singlePluginCategoryName, skills: singles))
        }
        declared.append(contentsOf: multiSkillPlugins)
        result.append(contentsOf: declared.sorted { $0.name < $1.name })

        categories = applyTranslations(to: result)
    }

    /// 그룹 선언 읽기. `<claudeDirectory>/skillbook-groups.json`(스킬 이름 → 카테고리 이름)에
    /// 적힌 개인 스킬은 "내 스킬" 대신 그 카테고리로 간다. 남이 만든 스킬 묶음이 개인 폴더에
    /// 통째로 설치되는 경우(플러그인이 아니라 `~/.claude/skills/`로 들어오는 배포본)를 위한 것 —
    /// SKILL.md에는 출처를 알 수 있는 표시가 없어서 추론할 수 없고, 선언받는 수밖에 없다.
    /// 파일이 없거나 깨졌으면 전부 "내 스킬"에 남는다.
    private func declaredGroups() -> [String: String] {
        let url = claudeDirectory.appendingPathComponent("skillbook-groups.json")
        guard let data = try? Data(contentsOf: url),
              let groups = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
        return groups
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
                return Skill(id: skill.id, name: skill.name, description: translated)
            })
        }
    }
}
