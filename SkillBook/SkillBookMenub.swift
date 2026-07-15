//
//  SkillBookMenub.swift
//  SkillBook ↔ menub 허브 통합. 3계약:
//   1) 정적 액션(패널·폴더)을 매니페스트로 기록
//   2) URL(skillbook://action/<id>) 수신 시 해당 동작 실행
//   3) 허브가 관리 중이면 상태 아이템을 만들지 않음
//

import AppKit
import Foundation
import MenubKit

final class SkillBookMenub {
    let satellite = MenubSatellite(
        id: "skillbook",
        displayName: "SkillBook",
        urlScheme: "skillbook",
        bundleIdentifier: Bundle.main.bundleIdentifier,
        iconRef: "sf:books.vertical"
    )

    /// 매니페스트 기록 + 라우팅 핸들러 연결. (앱 실행 시 1회)
    func configure(showPanel: @escaping () -> Void, openSkillsFolder: @escaping () -> Void) {
        satellite.setActions([
            satellite.makeAction(id: "panel", title: "스킬 패널 보기", iconRef: "sf:books.vertical"),
            satellite.makeAction(id: "folder", title: "스킬 폴더 열기", iconRef: "sf:folder")
        ])
        satellite.setQuitAction { NSApplication.shared.terminate(nil) }   // 허브에서 종료
        _ = satellite.writeManifest()   // 계약 1

        satellite.onInvoke { actionID in   // 계약 2
            switch actionID {
            case "panel":  showPanel()
            case "folder": openSkillsFolder()
            default:       break
            }
        }
    }

    func route(_ url: URL) {
        _ = satellite.route(url)
    }

    /// 계약 3: 상태 아이템을 만들어야 하는가(허브가 관리하지 않는가).
    var shouldCreateStatusItem: Bool {
        satellite.shouldCreateStatusItem()
    }
}
