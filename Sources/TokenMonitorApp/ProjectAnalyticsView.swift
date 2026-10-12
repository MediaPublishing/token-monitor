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
                Text("Capacity").tag(PopoverScreen.dashboard)
                Text("Analysis").tag(PopoverScreen.analytics)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .accessibilityLabel("View")
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
                Text("Project usage").font(.title3.weight(.semibold))
                Spacer()
                Picker("", selection: $analytics.period) {
                    Text("Last 7 days").tag(AnalyticsPeriod.week)
                    Text("Last 30 days").tag(AnalyticsPeriod.month)
                }
                .labelsHidden()
                .accessibilityLabel("Period")
                .frame(width: 145)
            }
            .padding(.horizontal, 8)

            HStack {
                Picker("", selection: $analytics.grouping) {
                    Text("Projects").tag(AnalyticsGrouping.projects)
                    Text("Topics").tag(AnalyticsGrouping.topics)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityLabel("Grouping")
                .frame(width: 180)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(analytics.totalTokens.formatted()) tokens").font(.subheadline.weight(.semibold)).monospacedDigit()
                    Text("\(analytics.threadCount) threads").font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 8)

            Divider()
            Text("Share of recorded usage")
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
                            Button(showAll ? "Show less" : "Show all \(analytics.groups.count) groups") { showAll.toggle() }
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
            Text(analytics.refreshing ? "Reading local usage..." : "No recorded usage yet")
                .font(.subheadline.weight(.medium))
            Text(analytics.sources.isEmpty && !analytics.refreshing
                 ? "Select Codex or Claude Code in Settings."
                 : "No supported token counters are available for this period. Web chats are not included.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Button("Open Settings") { model.showSettingsInPopover() }.controlSize(.small)
        }
        .padding(8)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Local logs only").font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Text("Incomplete coverage").font(.caption2).foregroundStyle(.secondary)
                    .help("Selected local coding logs from the last 30 days only. No web chats or capacity estimates. Agents are linked to their parent thread where possible.")
            }
            ForEach(analytics.sources, id: \.provider) { source in
                Text("\(source.provider.title): \(source.state) · \(source.files) files\(source.omitted > 0 ? " · some data omitted" : "")")
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(2)
            }
            if let date = analytics.capturedAt {
                Text("Updated \(date, style: .relative)").font(.caption2).foregroundStyle(.secondary)
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
                        Text("\(group.threadCount) threads").font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(group.tokens.total.formatted(.number.notation(.compactName)))
                            .font(.subheadline.weight(.semibold)).monospacedDigit()
                            .help("\(group.tokens.total.formatted()) tokens")
                        Text(share.formatted(.percent.precision(.fractionLength(0))))
                            .font(.caption2).foregroundStyle(.secondary).monospacedDigit()
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(group.title), \(group.tokens.total.formatted()) tokens, \(group.threadCount) threads")
            .accessibilityValue(expanded ? "Expanded" : "Collapsed")
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
                        Button(showThreads ? "Hide threads" : "Show \(group.threadCount) threads") { showThreads.toggle() }
                        Spacer()
                        if analytics.grouping == .projects {
                            Button(editing ? "Cancel" : "Assignment...") {
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
            TextField("Project name (optional)", text: $projectName)
            TextField("Topic, e.g. Development", text: $topic)
            HStack {
                Text("Empty topic = unassigned").font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Button("Save") {
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
