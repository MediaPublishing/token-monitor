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
            if compact {
                compactHeader
            }

            VStack(alignment: .leading, spacing: 6) {
                if !compact {
                    Text("Token Monitor Settings")
                        .font(.title3.weight(.semibold))
                } else {
                    Text("Provider settings")
                        .font(.headline.weight(.semibold))
                }
                Text("Each provider uses its own persistent WebKit session. Browser cookies from Chrome or Arc are never reused.")
                    .font(compact ? .caption : .subheadline)
                    .foregroundStyle(.secondary)
            }

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
        .frame(width: compact ? AppDelegate.popoverWidth : 560, height: compact ? 456 : 420, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var compactHeader: some View {
        HStack(spacing: 8) {
            Button {
                model.showDashboardInPopover()
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Text("Settings")
                .font(.headline.weight(.semibold))

            Spacer()

            Button("Quit") {
                model.quitApplication()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }
}
