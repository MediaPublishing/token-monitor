import SwiftUI
import TokenMonitorCore

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    let compact: Bool

    init(compact: Bool = false) {
        self.compact = compact
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: compact ? 10 : 18) {
                PopoverHeaderView()

                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(compact ? "Settings" : "Token Monitor Settings")
                            .font(compact ? .headline.weight(.semibold) : .title3.weight(.semibold))
                        Text("Persistent WebKit sessions are kept across updates. Browser cookies are never reused.")
                            .font(compact ? .caption : .subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(compact ? 2 : nil)
                    }

                    Spacer(minLength: 0)

                    if compact {
                        Button("Quit App") {
                            model.quitApplication()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10)
                    ],
                    alignment: .leading,
                    spacing: 10
                ) {
                    appSettingsCard
                    providerSettingsCard
                    statusMenuSettingsCard
                    usageDetailsSettingsCard
                    updatesSettingsCard
                    debuggingSettingsCard
                }

                Spacer(minLength: 0)
            }
            .padding(compact ? 10 : 22)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(width: compact ? AppDelegate.popoverWidth : 560, height: 620, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func settingsCard<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            content()
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor))
        )
    }

    private var appSettingsCard: some View {
        settingsCard("App") {
            Toggle(isOn: launchAtLoginBinding) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Launch at login")
                        .font(.subheadline.weight(.semibold))
                    Text("Start Token Monitor automatically after restart.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
            .controlSize(compact ? .small : .regular)

            Text(model.launchAtLoginStatusText)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Button("Open Login Items...") {
                model.openLoginItemsSettings()
            }
            .buttonStyle(.bordered)
            .controlSize(compact ? .mini : .small)
        }
    }

    private var providerSettingsCard: some View {
        settingsCard("Providers") {
            Text("Manage your connected providers")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(settingsProviderStatuses, id: \.service) { status in
                Button {
                    if status.service == .openCodeGo && !model.openCodeGoEnabled {
                        model.setOpenCodeGoEnabled(true)
                    }
                    model.openLogin(for: status.service)
                } label: {
                    HStack(spacing: 8) {
                        Text(status.service.displayName)
                            .font(.subheadline)
                        Spacer(minLength: 0)
                        Text(providerStatusLabel(for: status))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(providerStatusColor(for: status))
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)

                if status.service != .openCodeGo {
                    Divider()
                }
            }
        }
    }

    private var statusMenuSettingsCard: some View {
        settingsCard("Status menu") {
            Toggle(isOn: statusMenuColorBinding) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Use colored status bars")
                        .font(.subheadline.weight(.semibold))
                    Text("Turn off for a black-and-white menu bar icon.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
            .controlSize(compact ? .small : .regular)

            Toggle(isOn: statusMenuPercentagesBinding) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Show percentages in menu bar")
                        .font(.subheadline.weight(.semibold))
                    Text("Show Claude and ChatGPT values next to the bars.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
            .controlSize(compact ? .small : .regular)
        }
    }

    private var usageDetailsSettingsCard: some View {
        settingsCard("Usage details") {
            Toggle(isOn: showUsageDetailsBinding) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Show usage details")
                        .font(.subheadline.weight(.semibold))
                    Text("Show Extra usage and Monthly limit / Balance in the overview.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
            .controlSize(compact ? .small : .regular)

            Text("Turn this off to keep the dashboard focused on remaining capacity and reset times.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var updatesSettingsCard: some View {
        #if MAS_BUILD
        settingsCard("Updates") {
            Text("Updates are delivered by the Mac App Store.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        #else
        settingsCard("Updates") {
            Toggle(isOn: automaticUpdateChecksBinding) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Automatically check for updates")
                        .font(.subheadline.weight(.semibold))
                    Text("Show update prompts automatically.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
            .controlSize(compact ? .small : .regular)

            Button("Check for Updates...") {
                model.checkForUpdates()
            }
            .buttonStyle(.bordered)
            .controlSize(compact ? .mini : .small)
        }
        #endif
    }

    private var debuggingSettingsCard: some View {
        settingsCard("Debugging") {
            Toggle(isOn: debugModeBinding) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Enable debug mode")
                        .font(.subheadline.weight(.semibold))
                    Text("Store redacted refresh diagnostics locally.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
            .controlSize(compact ? .small : .regular)

            Text("Reports open as drafts for review before submitting.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                Button("GitHub Issue Draft") {
                    model.openGitHubDebugReportDraft()
                }
                .buttonStyle(.bordered)
                .controlSize(compact ? .mini : .small)

                Button("Email Draft") {
                    model.openEmailDebugReportDraft()
                }
                .buttonStyle(.bordered)
                .controlSize(compact ? .mini : .small)
            }

            Button("Open Folder") {
                model.openDiagnosticsFolder()
            }
            .buttonStyle(.bordered)
            .controlSize(compact ? .mini : .small)
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { model.launchAtLoginEnabled },
            set: { model.setLaunchAtLoginEnabled($0) }
        )
    }

    private var automaticUpdateChecksBinding: Binding<Bool> {
        Binding(
            get: { model.automaticallyChecksForUpdates },
            set: { model.setAutomaticallyChecksForUpdates($0) }
        )
    }

    private var debugModeBinding: Binding<Bool> {
        Binding(
            get: { model.debugModeEnabled },
            set: { model.setDebugModeEnabled($0) }
        )
    }

    private var statusMenuColorBinding: Binding<Bool> {
        Binding(
            get: { model.statusMenuUsesColor },
            set: { model.setStatusMenuUsesColor($0) }
        )
    }

    private var statusMenuPercentagesBinding: Binding<Bool> {
        Binding(
            get: { model.statusMenuShowsPercentages },
            set: { model.setStatusMenuShowsPercentages($0) }
        )
    }

    private var showUsageDetailsBinding: Binding<Bool> {
        Binding(
            get: { model.showUsageDetails },
            set: { model.setShowUsageDetails($0) }
        )
    }

    private var settingsProviderStatuses: [ServiceStatus] {
        model.providerSettingsServices + [model.dashboardState.service(.openCodeGo)]
    }

    private func providerStatusLabel(for status: ServiceStatus) -> String {
        if status.service == .openCodeGo && !model.openCodeGoEnabled {
            return "Not connected"
        }
        return connectionLabel(for: status.connectionStatus)
    }

    private func providerStatusColor(for status: ServiceStatus) -> Color {
        if status.service == .openCodeGo && !model.openCodeGoEnabled {
            return .secondary
        }
        return connectionColor(for: status.connectionStatus)
    }

    private func connectionLabel(for status: ServiceConnectionStatus) -> String {
        switch status {
        case .healthy:
            return "Healthy"
        case .refreshing:
            return "Refreshing"
        case .stale:
            return "Stale"
        case .authRequired:
            return "Needs login"
        case .error:
            return "Error"
        }
    }

    private func connectionColor(for status: ServiceConnectionStatus) -> Color {
        switch status {
        case .healthy:
            return .green
        case .refreshing:
            return .blue
        case .stale:
            return .orange
        case .authRequired:
            return .yellow
        case .error:
            return .red
        }
    }

}
