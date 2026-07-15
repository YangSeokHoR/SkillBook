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
                                // 카테고리를 접으면 그 안 스킬의 펼침 상태도 비운다 —
                                // 안 그러면 hasExpanded가 true로 남아 패널 높이가 실제 콘텐츠보다 커진다.
                                for skill in category.skills { expandedSkillIDs.remove(skill.id) }
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
