import AppKit
import SwiftUI

/// 클릭해도 다른 앱(Claude)의 포커스를 빼앗지 않는 플로팅 패널.
final class FloatingPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        animationBehavior = .utilityWindow
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// 플로팅 패널의 생성·표시·숨김·높이 조절을 담당.
final class PanelController {
    static let panelWidth: CGFloat = 320
    /// 패널을 처음 만들 때의 높이. 저장된 위치 복원 수식의 기준이기도 하므로
    /// 단일 출처로 둔다. (저장은 상단 모서리 maxY를 기록하고, 복원 시 이 값을 뺀다)
    private static let initialHeight: CGFloat = 200

    private var panel: FloatingPanel?
    private let store: SkillStore
    private var lastContentHeight: CGFloat = 0
    /// didMove 옵저버 토큰. deinit에서 해제하기 위해 보관한다.
    private var moveObserver: NSObjectProtocol?

    private let frameKey = "SkillBook.panelTopOrigin"
    /// 모든 항목이 접힌 상태의 콘텐츠 높이 (펼침 시 늘어날 양 계산의 기준)
    private var collapsedContentHeight: CGFloat = 0

    init(store: SkillStore) {
        self.store = store
    }

    deinit {
        if let moveObserver {
            NotificationCenter.default.removeObserver(moveObserver)
        }
    }

    func show() {
        if panel == nil { buildPanel() }
        // 숨김 동안 목록이 바뀌었을 수 있으니, 다음 높이 콜백이 무시되지 않도록
        // 캐시를 리셋해 재표시 시 항상 콘텐츠에 맞게 다시 맞춘다.
        lastContentHeight = 0
        panel?.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func buildPanel() {
        let origin = savedOrigin() ?? defaultOrigin()
        let rect = NSRect(origin: origin, size: NSSize(width: Self.panelWidth, height: Self.initialHeight))
        let panel = FloatingPanel(contentRect: rect)
        // contentView를 설정하는 순간 SwiftUI 초기 레이아웃이 동기 실행되어
        // 높이 콜백(adjustHeight)이 호출되므로, 반드시 그 전에 self.panel을 할당한다.
        self.panel = panel

        let root = SkillListView(
            store: store,
            onHeightChange: { [weak self] height, hasExpanded in
                // SwiftUI 레이아웃 도중 윈도우 리사이즈가 일어나지 않도록 다음 런루프로 미룸
                DispatchQueue.main.async { self?.adjustHeight(to: height, hasExpanded: hasExpanded) }
            },
            onRefresh: { [weak self] in self?.store.reload() }
        )
        let hosting = NSHostingView(rootView: root)
        // 기본 sizingOptions는 SwiftUI 이상적 크기로 윈도우를 고정하려고 해서
        // 수동 setFrame과 충돌한다. 비워서 윈도우 크기를 전적으로 수동 제어.
        hosting.sizingOptions = []
        panel.contentView = hosting

        // 위치 저장 (옵저버 토큰을 보관해 deinit에서 해제)
        moveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification, object: panel, queue: .main
        ) { [weak self] _ in
            self?.saveOrigin()
        }
    }

    /// 접힌 상태(펼친 항목 없음)일 때의 최대 높이 — 넘치면 내부 스크롤.
    /// 불러오기로 항목이 늘어도 새 항목이 곧바로 보이도록 넉넉하게 잡는다.
    static let collapsedMaxHeight: CGFloat = 420

    /// 콘텐츠 높이에 맞춰 윈도우 높이를 부드럽게 조절.
    /// 펼친 항목이 없으면 컴팩트한 기본 크기(내부 스크롤)를 유지하고,
    /// 펼친 항목이 있을 때만 상단을 고정한 채 아래로 늘어난다 (화면 초과 시 제한).
    private func adjustHeight(to contentHeight: CGFloat, hasExpanded: Bool) {
        guard let panel else { return }
        guard abs(contentHeight - lastContentHeight) > 0.5 else { return }
        lastContentHeight = contentHeight
        #if DEBUG
        print("[SkillBook] contentHeight: \(contentHeight), expanded: \(hasExpanded), panel: \(panel.frame.size)")
        #endif

        let screen = panel.screen ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

        var frame = panel.frame
        let topY = frame.maxY
        let screenLimit = topY - visible.minY - 8

        if !hasExpanded { collapsedContentHeight = contentHeight }

        // 기본 높이: 접힌 목록 크기 (60 ~ collapsedMaxHeight 범위로 제한)
        let base = min(max(collapsedContentHeight, 60), Self.collapsedMaxHeight)
        let newHeight: CGFloat
        if hasExpanded {
            // 기본 높이 + 펼친 분량만큼만 증가 (다른 접힌 항목은 계속 스크롤 안에)
            let extra = max(0, contentHeight - collapsedContentHeight)
            newHeight = min(base + extra, screenLimit)
        } else {
            newHeight = min(base, screenLimit)
        }

        frame.origin.y = topY - newHeight
        frame.size.height = newHeight

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.22
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(frame, display: true)
        }
    }

    // MARK: - 위치 기억

    private func defaultOrigin() -> NSPoint {
        let visible = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        return NSPoint(x: visible.maxX - Self.panelWidth - 24, y: visible.maxY - 240)
    }

    /// 저장값은 [origin.x, 상단 모서리 maxY]. 패널은 위가 고정된 채 아래로
    /// 늘어나므로 maxY(상단)를 기준으로 복원한다.
    private func savedOrigin() -> NSPoint? {
        guard let arr = UserDefaults.standard.array(forKey: frameKey) as? [Double], arr.count == 2
        else { return nil }
        // 저장된 상단 모서리(maxY)에서 초기 높이를 빼 origin.y를 복원.
        return NSPoint(x: arr[0], y: arr[1] - Self.initialHeight)
    }

    private func saveOrigin() {
        guard let panel else { return }
        // 현재 높이와 무관하게 상단 모서리(maxY)를 저장 → 복원 시 위치가 어긋나지 않음.
        UserDefaults.standard.set([panel.frame.origin.x, panel.frame.maxY], forKey: frameKey)
    }
}
