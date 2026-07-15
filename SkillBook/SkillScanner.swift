import Foundation

/// SKILL.md 파일과 설치 정보를 읽어 Skill 목록으로 바꾸는 순수 함수 모음.
/// 읽기 전용 — 어디에도 쓰지 않는다.
enum SkillScanner {

    /// 디렉토리의 하위 폴더들에서 SKILL.md를 찾아 파싱한다. 폴더 이름순 정렬.
    /// SKILL.md가 없거나 읽을 수 없는 폴더는 조용히 건너뛴다 (관대한 에러 처리).
    static func scanSkillsDirectory(_ directory: URL) -> [Skill] {
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
                name: nonBlank(parsed.name) ?? entry.lastPathComponent,
                description: nonBlank(parsed.description) ?? "(설명 없음)"
            ))
        }
        return skills
    }

    /// 공백만 있거나 빈 문자열이면 nil로 취급 (폴백 트리거용)
    private static func nonBlank(_ value: String?) -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return value
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
