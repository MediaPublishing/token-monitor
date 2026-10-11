import SwiftUI
import TokenMonitorCore

struct DashboardTabsView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var analytics: ProjectAnalyticsModel

    var body: some View {
        if analytics.enabled {
            Picker("", selection: Binding(
                get: { model.popoverScreen },
                set: { if $0 == .analytics { model.showAnalyticsInPopover() } else { model.showDashboardInPopover() } }
            )) {
                Text("Kapazität").tag(PopoverScreen.dashboard)
                Text("Analyse").tag(PopoverScreen.analytics)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .accessibilityLabel("Ansicht")
            .frame(width: 190)
            .padding(.leading, 8)
        }
    }
}

struct ProjectAnalyticsView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var analytics: ProjectAnalyticsModel
    @State private var showAll = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PopoverHeaderView(analytics: analytics)
            DashboardTabsView(analytics: analytics)
            HStack {
                Text("Projektanalyse").font(.title3.weight(.semibold))
                Spacer()
                Picker("", selection: $analytics.period) {
                    Text("Letzte 7 Tage").tag(AnalyticsPeriod.week)
                    Text("Letzte 30 Tage").tag(AnalyticsPeriod.month)
                }
                .labelsHidden()
                .accessibilityLabel("Zeitraum")
                .frame(width: 145)
            }
            .padding(.horizontal, 8)

            HStack {
                Picker("", selection: $analytics.grouping) {
                    Text("Projekte").tag(AnalyticsGrouping.projects)
                    Text("Themen").tag(AnalyticsGrouping.topics)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityLabel("Gruppierung")
                .frame(width: 180)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(analytics.totalTokens.formatted()) Tokens").font(.subheadline.weight(.semibold)).monospacedDigit()
                    Text("\(analytics.threadCount) Threads").font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 8)

            Divider()
            Text("Anteil am erfassten Verbrauch")
                .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if analytics.groups.isEmpty {
                        emptyState
                    } else {
                        ForEach(showAll ? analytics.groups : Array(analytics.groups.prefix(5))) { group in
                            AnalyticsGroupRow(group: group, total: analytics.totalTokens, analytics: analytics)
                        }
                        if analytics.groups.count > 5 {
                            Button(showAll ? "Weniger anzeigen" : "Alle \(analytics.groups.count) Gruppen anzeigen") { showAll.toggle() }
                                .buttonStyle(.borderless)
                                .font(.caption)
                                .padding(8)
                        }
                    }
                }
            }

            if let error = analytics.errorText {
                Text(error).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Divider()
            footer
        }
        .padding(10)
        .frame(width: AppDelegate.popoverWidth, height: model.desiredPopoverHeight(), alignment: .top)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { analytics.refreshIfNeeded() }
        .onChange(of: analytics.grouping) { _, _ in showAll = false }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(analytics.refreshing ? "Lokale Verbrauchsdaten werden gelesen…" : "Noch kein Verbrauch erfasst")
                .font(.subheadline.weight(.medium))
            Text(analytics.sources.isEmpty && !analytics.refreshing
                 ? "Wähle Codex oder Claude Code in den Einstellungen."
                 : "Für diesen Zeitraum sind keine unterstützten Tokenzähler verfügbar. Webchats sind nicht enthalten.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Button("Einstellungen öffnen") { model.showSettingsInPopover() }.controlSize(.small)
        }
        .padding(8)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Nur lokale Protokolle").font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Text("Erfassung unvollständig").font(.caption2).foregroundStyle(.secondary)
                    .help("Nur ausgewählte lokale Coding-Protokolle der letzten 30 Tage. Keine Webchats oder Quota-Schätzung; Agenten werden nach Möglichkeit ihrem Hauptthread zugeordnet.")
            }
            ForEach(analytics.sources, id: \.provider) { source in
                Text("\(source.provider.title): \(source.state) · \(source.files) Dateien\(source.omitted > 0 ? " · ausgelassene Daten" : "")")
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(2)
            }
            if let date = analytics.capturedAt {
                Text("Aktualisiert \(date, style: .relative)").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 8)
    }
}

private struct AnalyticsGroupRow: View {
    let group: AnalyticsGroup
    let total: Int64
    @ObservedObject var analytics: ProjectAnalyticsModel
    @State private var expanded = false
    @State private var editing = false
    @State private var showThreads = false
    @State private var projectName = ""
    @State private var topic = ""

    private var share: Double { total > 0 ? Double(group.tokens.total) / Double(total) : 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button { expanded.toggle() } label: {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                        .font(.caption.weight(.semibold)).frame(width: 12)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(group.title).font(.subheadline.weight(.semibold)).lineLimit(1).help(group.title)
                        Text("\(group.threadCount) Threads").font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(group.tokens.total.formatted(.number.notation(.compactName)))
                            .font(.subheadline.weight(.semibold)).monospacedDigit()
                            .help("\(group.tokens.total.formatted()) Tokens")
                        Text(share.formatted(.percent.precision(.fractionLength(0))))
                            .font(.caption2).foregroundStyle(.secondary).monospacedDigit()
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(group.title), \(group.tokens.total.formatted()) Tokens, \(group.threadCount) Threads")
            .accessibilityValue(expanded ? "Aufgeklappt" : "Eingeklappt")
            AnalyticsShareBar(share: share, color: .mint)
                .padding(.leading, 22)

            if expanded {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(AnalyticsProvider.allCases, id: \.self) { provider in
                        if let tokens = group.providerTokens[provider] {
                            HStack(spacing: 8) {
                                Text(provider.title).font(.caption).frame(width: 82, alignment: .leading)
                                AnalyticsShareBar(share: Double(tokens.total) / Double(max(1, group.tokens.total)),
                                                  color: provider == .codex ? .mint : .orange)
                                Text(tokens.total.formatted(.number.notation(.compactName)))
                                    .font(.caption.monospacedDigit()).frame(width: 72, alignment: .trailing)
                            }
                        }
                    }
                    HStack {
                        Button(showThreads ? "Threads ausblenden" : "\(group.threadCount) Threads anzeigen") { showThreads.toggle() }
                        Spacer()
                        if analytics.grouping == .projects {
                            Button(editing ? "Abbrechen" : "Zuordnung…") {
                                let saved = analytics.assignment(for: group.projectKeys.sorted().first ?? "")
                                projectName = saved.projectName
                                topic = saved.topic
                                editing.toggle()
                            }
                        }
                    }
                    .buttonStyle(.borderless).font(.caption)
                    if editing { assignmentEditor }
                    if showThreads {
                        ForEach(group.threadTokens.keys.sorted(), id: \.self) { id in
                            HStack {
                                Text(shortThreadLabel(id)).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                                Spacer()
                                Text((group.threadTokens[id]?.total ?? 0).formatted(.number.notation(.compactName)))
                                    .font(.caption2.monospacedDigit())
                            }
                        }
                    }
                }
                .padding(.leading, 22)
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 12)
        .overlay(alignment: .bottom) { Divider() }
    }

    private var assignmentEditor: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Projektname (optional)", text: $projectName)
            TextField("Thema, z. B. Entwicklung", text: $topic)
            HStack {
                Text("Leeres Thema = nicht zugeordnet").font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Button("Speichern") {
                    analytics.assign(keys: group.projectKeys, projectName: projectName, topic: topic)
                    editing = false
                }.controlSize(.small)
            }
        }
        .textFieldStyle(.roundedBorder)
    }

    private func shortThreadLabel(_ id: String) -> String {
        let parts = id.split(separator: ":")
        let provider = id.hasPrefix("codex:") ? "Codex" : "Claude Code"
        return "\(provider) · \(String(parts.dropFirst().joined(separator: ":").prefix(12)))"
    }
}

private struct AnalyticsShareBar: View {
    let share: Double
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3).fill(Color(nsColor: .controlBackgroundColor))
                RoundedRectangle(cornerRadius: 3).fill(color)
                    .frame(width: geometry.size.width * max(0, min(1, share)))
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }
}
