import SwiftUI
import TokenMonitorCore

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    let compact: Bool

    init(compact: Bool = false) {
        self.compact = compact
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 14 : 20) {
            PopoverHeaderView()

            if compact {
                HStack {
                    Spacer()

                    Button("Quit App") {
                        model.quitApplication()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                if !compact {
                    Text("Token Monitor Settings")
                        .font(.title3.weight(.semibold))
                } else {
                    Text("Provider settings")
                        .font(.headline.weight(.semibold))
                }
                Text("Token Monitor uses a persistent WebKit session that is kept across app updates. Browser cookies from Chrome or Arc are never reused.")
                    .font(compact ? .caption : .subheadline)
                    .foregroundStyle(.secondary)
            }

            Toggle(isOn: launchAtLoginBinding) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Launch at login")
                        .font(.subheadline.weight(.semibold))
                    Text("Open Token Monitor automatically after each restart.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
            .controlSize(compact ? .small : .regular)
            .padding(.vertical, compact ? 2 : 4)

            VStack(alignment: .leading, spacing: 6) {
                Text(model.launchAtLoginStatusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Open Login Items...") {
                    model.openLoginItemsSettings()
                }
                .buttonStyle(.bordered)
                .controlSize(compact ? .small : .regular)
            }
            .padding(.bottom, compact ? 2 : 4)

            #if MAS_BUILD
            VStack(alignment: .leading, spacing: 2) {
                Text("Updates")
                    .font(.subheadline.weight(.semibold))
                Text("Updates are delivered by the Mac App Store.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, compact ? 2 : 4)
            #else
            Toggle(isOn: automaticUpdateChecksBinding) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Automatically check for updates")
                        .font(.subheadline.weight(.semibold))
                    Text("Use Sparkle to watch the GitHub release feed and offer new versions.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
            .controlSize(compact ? .small : .regular)
            .padding(.vertical, compact ? 2 : 4)

            Button("Check for Updates...") {
                model.checkForUpdates()
            }
            .buttonStyle(.bordered)
            .controlSize(compact ? .small : .regular)
            #endif

            VStack(alignment: .leading, spacing: 8) {
                Text("Debugging")
                    .font(.headline)

                Toggle(isOn: debugModeBinding) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enable debug mode")
                            .font(.subheadline.weight(.semibold))
                        Text("Store redacted refresh diagnostics locally when a provider refresh runs.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
                .controlSize(compact ? .small : .regular)

                Text("Reports open as drafts. Review before submitting because usage values and page text can still be account-specific.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Button("GitHub Issue Draft") {
                        model.openGitHubDebugReportDraft()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(compact ? .small : .regular)

                    Button("Email Draft") {
                        model.openEmailDebugReportDraft()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(compact ? .small : .regular)

                    Button("Open Folder") {
                        model.openDiagnosticsFolder()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(compact ? .small : .regular)
                }
            }
            .padding(compact ? 10 : 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(nsColor: .textBackgroundColor))
            )

            ForEach(model.dashboardState.services, id: \.service) { status in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(status.service.displayName)
                                .font(.headline)
                            Text(model.stateDescription(for: status))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button(status.connectionStatus == .authRequired ? "Connect" : "Reconnect") {
                            model.openLogin(for: status.service)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(compact ? .small : .regular)

                        Button("Refresh") {
                            model.refresh(status.service, trigger: .manual, force: true)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(compact ? .small : .regular)
                    }

                    if status.service == .claude {
                        Text("Claude note: “Continue with Google” can fail inside embedded app webviews. Use “Continue with email” and enter the same Gmail address instead. If your Claude account is Google-only with no email-password fallback, this in-app Claude login path will not work reliably.")
                            .font(compact ? .caption2 : .caption)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            Button("Open Claude In Browser") {
                                model.openUsagePageInDefaultBrowser(for: .claude)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(compact ? .small : .regular)

                            if !compact {
                                Button("Quit App") {
                                    model.quitApplication()
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    } else {
                        HStack(spacing: 8) {
                            Button("Open In Browser") {
                                model.openUsagePageInDefaultBrowser(for: status.service)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(compact ? .small : .regular)

                            if !compact {
                                Button("Quit App") {
                                    model.quitApplication()
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
                .padding(compact ? 10 : 14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(nsColor: .textBackgroundColor))
                )
            }

            if !compact {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Local storage")
                        .font(.headline)
                    Text("Snapshots are stored at:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(model.snapshotPathText)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)

                    Text("Debug dumps are stored at:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                    Text(model.diagnosticsPathText)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
            }

            Spacer()
        }
        .padding(compact ? 10 : 22)
        .frame(width: compact ? AppDelegate.popoverWidth : 560, height: compact ? 620 : 560, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
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
}
