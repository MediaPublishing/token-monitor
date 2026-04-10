import SwiftUI

struct PopoverRootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Group {
            switch model.popoverScreen {
            case .dashboard:
                DashboardPopoverView()
            case .settings:
                SettingsView(compact: true)
            }
        }
    }
}
