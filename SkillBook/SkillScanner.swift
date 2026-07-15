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
