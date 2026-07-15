import AppKit

/// Claude 데스크톱 앱이 최전면인지 감지한다.
/// 내 앱 자신이 최전면이 된 경우(플로팅 윈도우 조작 중)도 "표시 유지"로 취급한다.
final class AppDetector {
    /// true = 패널 표시, false = 숨김
    var onChange: ((Bool) -> Void)?

    private static let claudeBundleID = "com.anthropic.claudefordesktop"
    private var observer: NSObjectProtocol?

    func start() {
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self,
                  let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            else { return }
            self.onChange?(Self.shouldShow(for: app))
        }
        // 시작 시점의 최전면 앱 반영
        if let front = NSWorkspace.shared.frontmostApplication {
            onChange?(Self.shouldShow(for: front))
        }
    }

    func stop() {
        if let observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        observer = nil
    }

    private static func shouldShow(for app: NSRunningApplication) -> Bool {
        // 내 앱 자신
        if app.processIdentifier == ProcessInfo.processInfo.processIdentifier {
            return true
        }
        // Claude 데스크톱 앱 (번들 ID 우선, 보조로 앱 이름 확인)
        if app.bundleIdentifier == claudeBundleID { return true }
        if app.localizedName == "Claude" { return true }
        return false
    }
}
