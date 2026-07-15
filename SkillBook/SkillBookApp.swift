import AppKit
import SwiftUI

@main
struct SkillBookApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        // 메인 윈도우 없는 메뉴바 앱 — Settings 씬은 빈 껍데기
        Settings { EmptyView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = SkillStore()
    private let detector = AppDetector()
    private let menub = SkillBookMenub()
    private var panelController: PanelController!
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // Dock 아이콘 없는 메뉴바 앱

        panelController = PanelController(store: store)

        // menub 통합: 매니페스트 기록 + 라우팅 연결 (계약 1·2)
        menub.configure(
            showPanel: { [weak self] in self?.showPanel() },
            openSkillsFolder: { Self.openSkillsFolder() }
        )

        // 계약 3: 허브가 관리 중이면 자기 상태 아이템을 만들지 않는다(실행 시 결정).
        if menub.shouldCreateStatusItem {
            setupStatusItem()
        }

        detector.onChange = { [weak self] shouldShow in
            if shouldShow {
                self?.showPanel()
            } else {
                self?.panelController.hide()
            }
        }
        detector.start()
    }

    // 계약 2: skillbook://action/<id> 수신 → 해당 동작 실행
    func application(_ application: NSApplication, open urls: [URL]) {
        urls.forEach { menub.route($0) }
    }

    /// 패널 표시 직전에 항상 디스크를 다시 스캔한다 (스펙: 표시 시마다 reload).
    private func showPanel() {
        store.reload()
        panelController.show()
    }

    private static func openSkillsFolder() {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/skills", isDirectory: true)
        NSWorkspace.shared.open(url)
    }

    // MARK: - 메뉴바

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "books.vertical",
                accessibilityDescription: "SkillBook"
            )
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "스킬 패널 보기", action: #selector(showPanelAction), keyEquivalent: "p"))
        menu.addItem(NSMenuItem(title: "스킬 폴더 열기", action: #selector(openFolderAction), keyEquivalent: "o"))
        menu.addItem(NSMenuItem(title: "새로고침", action: #selector(refreshAction), keyEquivalent: "r"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "SkillBook 종료", action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        statusItem.menu = menu
    }

    @objc private func showPanelAction() { showPanel() }
    @objc private func openFolderAction() { Self.openSkillsFolder() }
    @objc private func refreshAction() { store.reload() }
    @objc private func quit() { NSApp.terminate(nil) }
}
