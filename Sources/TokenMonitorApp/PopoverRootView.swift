import SwiftUI

struct PopoverRootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Group {
            switch model.popoverScreen {
            case .dashboard:
                DashboardPopoverView()
            case .analytics:
                ProjectAnalyticsView(analytics: model.analytics)
            case .settings:
                SettingsView(compact: true, analytics: model.analytics)
            }
        }
    }
}
