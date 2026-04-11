import SwiftUI

struct PopoverHeaderView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Token Monitor")
                    .font(.headline.weight(.semibold))
                Text(model.lastRefreshText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.leading, 8)

            Spacer(minLength: 6)

            headerButton(systemImage: "arrow.clockwise", action: {
                model.refreshAll(trigger: .manual)
            })
            .opacity(model.isRefreshing ? 0.5 : 1.0)
            .disabled(model.isRefreshing)
            .help("Refresh both services")

            headerButton(
                systemImage: "chart.bar.xaxis",
                isSelected: model.popoverScreen == .dashboard,
                action: {
                    model.showDashboardInPopover()
                }
            )
            .help("Dashboard")

            headerButton(
                systemImage: "gearshape",
                isSelected: model.popoverScreen == .settings,
                action: {
                    model.showSettingsInPopover()
                }
            )
            .help("Settings")

            headerButton(systemImage: "xmark", action: {
                AppDelegate.shared?.closePopover()
            })
            .help("Close popover")
        }
    }

    private func headerButton(
        systemImage: String,
        isSelected: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 28, height: 24)
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? Color(nsColor: .selectedControlColor) : Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.black.opacity(isSelected ? 0.14 : 0.10), lineWidth: 1)
        )
    }
}
