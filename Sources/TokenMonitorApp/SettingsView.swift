import SwiftUI
import TokenMonitorCore

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject private var updates = AppUpdateController.shared
    @ObservedObject private var analytics: ProjectAnalyticsModel
    @State private var renamingAccountID: UUID?
    @State private var draftAccountName = ""
    let compact: Bool

    init(compact: Bool = false, analytics: ProjectAnalyticsModel = AppModel.shared.analytics) {
        self.analytics = analytics
        self.compact = compact
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    Text("Settings").font(.headline.weight(.semibold))

                    Spacer(minLength: 0)

                    if compact {
                        Button("Quit App") {
                            model.quitApplication()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

                providerSettingsCard.id("settings-providers")
                Grid(horizontalSpacing: 10, verticalSpacing: 8) {
                    GridRow(alignment: .top) {
                        appSettingsCard
                        statusMenuSettingsCard
                    }
                    .id("settings-app")
                    GridRow(alignment: .top) {
                        usageDetailsSettingsCard
                        updatesSettingsCard
                    }
                    .id("settings-usage")
                    GridRow(alignment: .top) {
                        analyticsSettingsCard
                        debuggingSettingsCard
                    }
                    .id("settings-projects")
                }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .scrollTargetLayout()
        .onAppear { model.resetReminders.refreshAuthorization() }
        .alert("Rename account", isPresented: Binding(
            get: { renamingAccountID != nil },
            set: { if !$0 { renamingAccountID = nil } }
        )) {
            TextField("Account name", text: $draftAccountName)
            Button("Save") {
                if let id = renamingAccountID { model.renameAccount(id, to: draftAccountName) }
                renamingAccountID = nil
            }
            Button("Cancel", role: .cancel) { renamingAccountID = nil }
        } message: {
            Text("Use a short name to distinguish this account in the dashboard.")
        }
    }

    private func settingsCard<Content: View>(
        _ title: String,
        spacing: CGFloat = 6,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: spacing) {
            Text(title)
                .font(.headline)
            content()
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5)
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
                if !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
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
                description: "Start automatically after restart.",
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
        settingsCard("Providers", spacing: 4) {
            ForEach([ServiceKind.chatGPT, .claude, .openCodeGo], id: \.self) { service in
                ForEach(Array(model.providerSettingsServices(for: service).enumerated()), id: \.element.accountID) { index, status in
                    HStack(spacing: 8) {
                        ProviderLogoView(service: service)
                        Button {
                            model.openLogin(accountID: status.accountID)
                        } label: {
                            Text(status.accountName)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .help("\(service.displayName): \(status.accountName)")
                        Text(providerStatusLabel(for: status))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(providerStatusColor(for: status))
                            .frame(width: 88, alignment: .trailing)
                        let selectedAccounts = model.menuBarAccounts(for: service)
                        let selected = selectedAccounts.contains(where: { $0.id == status.accountID })
                        Button {
                            if selected { model.hideMenuBarAccount(status.accountID, for: service) }
                            else { model.showMenuBarAccountAlongside(status.accountID, for: service) }
                        } label: {
                            Image(systemName: "menubar.rectangle")
                                .foregroundStyle(selected ? Color.primary : Color.secondary)
                                .opacity(selected ? 1 : 0.35)
                        }
                            .buttonStyle(.plain)
                            .frame(width: 18)
                            .accessibilityLabel("\(selected ? "Hide" : "Show") \(status.accountName) \(selected ? "from" : "in") menu bar")
                            .help(model.menuBarPositionDescription(for: status.accountID) + ". Click to show or hide; the account stays connected.")
                        Menu {
                            Button("Connect / Reconnect") { model.openLogin(accountID: status.accountID) }
                            Button("Rename...") {
                                draftAccountName = status.accountName
                                renamingAccountID = status.accountID
                            }
                            if model.menuBarAccountID(for: service) != status.accountID {
                                Button(selected ? "Show first for \(service.displayName)" : "Show in menu bar") {
                                    model.setMenuBarAccount(status.accountID, for: service)
                                }
                            }
                            if !selected {
                                Button("Add to menu bar") {
                                    model.showMenuBarAccountAlongside(status.accountID, for: service)
                                }
                                .help("One bar per selected account. Up to six visible; additional accounts appear as +N.")
                            } else {
                                Button("Hide from menu bar") { model.hideMenuBarAccount(status.accountID, for: service) }
                            }
                            Divider()
                            Button("Switch account...") {
                                model.openLogin(accountID: status.accountID, replacingExistingSession: true)
                            }
                            Button("Disconnect", role: .destructive) {
                                model.disconnect(accountID: status.accountID)
                            }
                            if !status.isPrimary {
                                Button("Remove account", role: .destructive) {
                                    model.removeAccount(status.accountID)
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.hidden)
                        .frame(width: 22)
                        if index == 0 {
                            Button { model.addAccount(for: service) } label: {
                                Image(systemName: "plus").frame(width: 22, height: 24)
                            }
                            .buttonStyle(.borderless)
                            .help("Add \(service.displayName) account")
                            .accessibilityLabel("Add \(service.displayName) account")
                        } else {
                            Color.clear.frame(width: 22, height: 24)
                        }
                    }
                    .frame(minHeight: 28)
                }
                if service != .openCodeGo {
                    Divider()
                }
            }
        }
    }

    private var statusMenuSettingsCard: some View {
        settingsCard("Status menu", spacing: 6) {
            settingsToggle(
                "Use colored status bars",
                description: "",
                isOn: statusMenuColorBinding
            )
            .help("Turn off for monochrome menu-bar bars.")

            settingsToggle(
                "Menu bar percentages",
                description: "",
                isOn: statusMenuPercentagesBinding
            )
            .help("Show limit percentages next to the menu-bar bars.")

            HStack(spacing: 8) {
                Text("Bar layout")
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 0)
                Picker("Bar layout", selection: statusMenuAccountArrangementBinding) {
                    ForEach(MenuBarAccountArrangement.allCases) { arrangement in
                        Text(arrangement.title).tag(arrangement)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()
            }
            .help("Compact groups all accounts. By provider groups accounts in one column per provider. By account puts each selected account in its own column; with Both, Session is above Total. Up to six accounts are visible; more appear as +N. By account uses more menu-bar width; choose Compact if macOS hides the icon.")
            Text(model.statusMenuAccountArrangement.summary)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 3) {
                Text("Limit display")
                    .font(.subheadline.weight(.semibold))

                Picker("Limit display", selection: statusMenuLimitDisplayBinding) {
                    ForEach(StatusMenuLimitDisplay.allCases) { display in
                        Text(display.title).tag(display)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(maxWidth: .infinity)
            }
            .help("Session, total, or both for every selected account. Both uses a combined bar in Compact and By provider; By account shows Session above Total.")
        }
    }

    private var usageDetailsSettingsCard: some View {
        settingsCard("Usage details") {
            settingsToggle(
                "Show usage details",
                description: "Extra usage, limits and balance.",
                isOn: showUsageDetailsBinding
            )

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
        settingsCard("Updates", spacing: 6) {
            settingsToggle(
                "Automatically check for updates",
                description: "Check hourly.",
                isOn: automaticUpdateChecksBinding
            )

            settingsToggle(
                "Install on quit",
                description: "No forced restart.",
                isOn: Binding(get: { updates.automaticDownloadsEnabled },
                              set: { updates.automaticallyDownloadsUpdates = $0 })
            )
            .help("Download signed updates automatically and install when Token Monitor quits. macOS may still require authorization. Existing preferences are preserved.")

            Button("Check for Updates...") {
                model.checkForUpdates()
            }
            .buttonStyle(.bordered)
            .controlSize(compact ? .mini : .small)
            .disabled(updates.isPreparingUpdate)
            Text(updates.statusText)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let nextCheck = updates.nextCheckDate {
                Text("Next check: \(nextCheck, style: .time)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
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
                description: "Redacted logs, local only.",
                isOn: debugModeBinding
            )

            Text("Review reports before sending.")
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

    private var analyticsSettingsCard: some View {
        settingsCard("Project details") {
            settingsToggle(
                "Show analysis",
                description: "Local usage by project or topic.",
                isOn: Binding(get: { analytics.enabled }, set: { model.setProjectAnalyticsEnabled($0) })
            )
            if analytics.enabled {
                HStack(spacing: 8) {
                    Toggle("Codex", isOn: Binding(get: { analytics.codexEnabled },
                        set: { analytics.setSource(.codex, enabled: $0) }))
                    Toggle("Claude Code", isOn: Binding(get: { analytics.claudeEnabled },
                        set: { analytics.setSource(.claudeCode, enabled: $0) }))
                }
                .toggleStyle(.checkbox)
                .controlSize(.small)
                Text("Local coding logs only. No web chats.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Menu {
                    Button("Reset assignments") { analytics.clearAssignments() }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 24)
            }
        }
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

    private var statusMenuAccountArrangementBinding: Binding<MenuBarAccountArrangement> {
        Binding(
            get: { model.statusMenuAccountArrangement },
            set: { model.setStatusMenuAccountArrangement($0) }
        )
    }

    private var showUsageDetailsBinding: Binding<Bool> {
        Binding(
            get: { model.showUsageDetails },
            set: { model.setShowUsageDetails($0) }
        )
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
