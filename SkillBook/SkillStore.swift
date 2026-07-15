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
