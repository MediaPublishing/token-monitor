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
                        Text("Updates preserve your sign-in. Providers may still require reauthentication.")
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

                VStack(spacing: 10) {
                    settingsRow(height: 152) {
                        appSettingsCard
                        providerSettingsCard
                    }
                    settingsRow(height: 205) {
                        statusMenuSettingsCard
                        usageDetailsSettingsCard
                    }
                    settingsRow(height: 174) {
                        updatesSettingsCard
                        debuggingSettingsCard
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(compact ? 10 : 22)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(width: compact ? AppDelegate.popoverWidth : 560, height: 700, alignment: .topLeading)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor))
        )
    }

    private func settingsRow<Left: View, Right: View>(
        height: CGFloat,
        @ViewBuilder content: () -> TupleView<(Left, Right)>
    ) -> some View {
        let views = content().value
        return HStack(alignment: .top, spacing: 10) {
            views.0
                .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .topLeading)
            views.1
                .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .topLeading)
        }
    }

    private func settingsToggle(
        _ title: String,
        description: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(compact ? .small : .regular)
                .fixedSize()
        }
    }

    private var appSettingsCard: some View {
        settingsCard("App") {
            settingsToggle(
                "Launch at login",
                description: "Start Token Monitor automatically after restart.",
                isOn: launchAtLoginBinding
            )

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
                HStack(spacing: 6) {
                    Button {
                        connectOrReconnect(status)
                    } label: {
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
                    .buttonStyle(.plain)

                    if providerHasAccountActions(status) {
                        Menu {
                            Button("Reconnect") {
                                model.openLogin(for: status.service)
                            }
                            Button("Switch account...") {
                                model.switchAccount(for: status.service)
                            }
                            Divider()
                            Button("Disconnect", role: .destructive) {
                                model.disconnect(status.service)
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                        .help("\(status.service.displayName) account options")
                    }
                }

                if status.service != .openCodeGo {
                    Divider()
                }
            }
        }
    }

    private var statusMenuSettingsCard: some View {
        settingsCard("Status menu") {
            settingsToggle(
                "Use colored status bars",
                description: "Turn off for a black-and-white menu bar icon.",
                isOn: statusMenuColorBinding
            )

            settingsToggle(
                "Menu bar percentages",
                description: "Show the selected limit next to every status bar.",
                isOn: statusMenuPercentagesBinding
            )

            VStack(alignment: .leading, spacing: 5) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Limit display")
                        .font(.subheadline.weight(.semibold))
                    Text("Session, total, or both.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Picker("Limit display", selection: statusMenuLimitDisplayBinding) {
                    ForEach(StatusMenuLimitDisplay.allCases) { display in
                        Text(display.title).tag(display)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func connectOrReconnect(_ status: ServiceStatus) {
        model.openLogin(for: status.service)
    }

    private func providerHasAccountActions(_ status: ServiceStatus) -> Bool {
        if status.service == .openCodeGo && !model.openCodeGoEnabled {
            return false
        }
        return status.snapshot != nil || status.connectionStatus != .authRequired
    }

    private var usageDetailsSettingsCard: some View {
        settingsCard("Usage details") {
            settingsToggle(
                "Show usage details",
                description: "Show Extra usage and Monthly limit / Balance in the overview.",
                isOn: showUsageDetailsBinding
            )

            Text("Turn this off to keep the dashboard focused on remaining capacity and reset times.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Divider()
            ResetReminderSettingsView(reminders: model.resetReminders)
        }
    }

    @ViewBuilder
    private var updatesSettingsCard: some View {
        #if MAS_BUILD
        settingsCard("Updates") {
            Text("Updates are delivered by the Mac App Store.")
                .font(.caption)
                .foregroundStyle(.secondary)
            versionLabel
        }
        #else
        settingsCard("Updates") {
            settingsToggle(
                "Automatically check for updates",
                description: "Show update prompts automatically.",
                isOn: automaticUpdateChecksBinding
            )

            Button("Check for Updates...") {
                model.checkForUpdates()
            }
            .buttonStyle(.bordered)
            .controlSize(compact ? .mini : .small)
            versionLabel
        }
        #endif
    }

    private var versionLabel: some View {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        return Text(build.map { "Version \(version) (\($0))" } ?? "Version \(version)")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .textSelection(.enabled)
    }

    private var debuggingSettingsCard: some View {
        settingsCard("Debugging") {
            settingsToggle(
                "Enable debug mode",
                description: "Store redacted refresh diagnostics locally.",
                isOn: debugModeBinding
            )

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

    private var statusMenuLimitDisplayBinding: Binding<StatusMenuLimitDisplay> {
        Binding(
            get: { model.statusMenuLimitDisplay },
            set: { model.setStatusMenuLimitDisplay($0) }
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
