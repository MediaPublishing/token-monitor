import SwiftUI
import TokenMonitorCore

struct ProjectAnalyticsView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var analytics: ProjectAnalyticsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Project usage").font(.title3.weight(.semibold))
                Spacer()
                Picker("Period", selection: $analytics.period) {
                    Text("Last 7 days").tag(AnalyticsPeriod.week)
                    Text("Last 30 days").tag(AnalyticsPeriod.month)
                }
                .labelsHidden()
                .accessibilityLabel("Period")
                .frame(width: 145)
            }
            HStack {
                if analytics.hasMeaningfulTopics {
                    Picker("Group by", selection: $analytics.grouping) {
                        Text("Projects").tag(AnalyticsGrouping.projects)
                        Text("Topics").tag(AnalyticsGrouping.topics)
                    }
                    .labelsHidden()
                    .accessibilityLabel("Grouping")
                    .frame(width: 120)
                } else {
                    Text("Share of recorded usage").font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Text("Recorded: \(analytics.totalTokens.formatted(.number.notation(.compactName))) tokens")
                    .font(.caption.weight(.semibold)).monospacedDigit()
                    .help("\(analytics.totalTokens.formatted()) recorded tokens")
            }
            Divider()

            if analytics.groups.isEmpty {
                emptyState
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(analytics.groups) { group in
                        AnalyticsGroupRow(group: group, total: analytics.totalTokens, analytics: analytics)
                            .id(group.id)
                    }
                }
                .scrollTargetLayout()
            }
            if let error = analytics.errorText {
                Text(error).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onAppear { analytics.refreshIfNeeded() }
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
}

struct AnalyticsCoverageFooter: View {
    @ObservedObject var analytics: ProjectAnalyticsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button { analytics.setSourceFooterExpanded(!analytics.sourceFooterExpanded) } label: {
                HStack {
                    Text("Local logs only · Incomplete coverage").font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: analytics.sourceFooterExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                }
            }
            .buttonStyle(.plain)
            .accessibilityValue(analytics.sourceFooterExpanded ? "Expanded" : "Collapsed")
            if analytics.sourceFooterExpanded {
                ForEach(analytics.sources, id: \.provider) { source in
                    Text("\(source.provider.title): \(source.state) · \(source.files) files\(source.omitted > 0 ? " · some data omitted" : "")")
                        .font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                }
                if let date = analytics.capturedAt {
                    Text("Updated \(date, style: .relative)").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct AnalyticsGroupRow: View {
    let group: AnalyticsGroup
    let total: Int64
    @ObservedObject var analytics: ProjectAnalyticsModel
    @State private var editing = false
    @State private var projectName = ""
    @State private var topic = ""

    private var expanded: Bool { analytics.expandedGroupIDs.contains(group.id) }
    private func share(_ tokens: Int64) -> Double { total > 0 ? Double(tokens) / Double(total) : 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Button { analytics.setExpanded(group.id, !expanded) } label: {
                    HStack(spacing: 8) {
                        Image(systemName: expanded ? "chevron.down" : "chevron.right")
                            .font(.caption.weight(.semibold)).frame(width: 18)
                        Text(group.title).font(.subheadline.weight(.semibold)).lineLimit(1).help(group.title)
                        Spacer(minLength: 8)
                        numbers(group.tokens.total)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(group.title), \(group.tokens.total.formatted()) tokens")
                .accessibilityValue(expanded ? "Expanded" : "Collapsed")
                Menu {
                    Button(editing ? "Cancel assignment" : "Assignment...") {
                        let saved = analytics.assignment(for: group.projectKeys.min() ?? "")
                        projectName = saved.projectName
                        topic = saved.topic
                        editing.toggle()
                    }
                } label: { Image(systemName: "ellipsis.circle") }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 22)
                .disabled(analytics.grouping != .projects)
                .accessibilityLabel("Project assignment")
            }
            AnalyticsShareBar(share: share(group.tokens.total))
                .padding(.leading, 26).padding(.trailing, 30)
            if expanded {
                ForEach(group.sortedThreadIDs, id: \.self) { id in
                    HStack(spacing: 8) {
                        ProviderLogoView(service: id.hasPrefix("codex:") ? .chatGPT : .claude)
                        Text(shortThreadLabel(id)).font(.caption).foregroundStyle(.secondary)
                            .lineLimit(1).help(id)
                        Spacer(minLength: 8)
                        numbers(group.threadTokens[id]?.total ?? 0)
                    }
                    .frame(minHeight: 28)
                    .padding(.trailing, 30)
                }
            }
            if editing { assignmentEditor.padding(.leading, 26) }
        }
        .padding(.horizontal, 8).padding(.vertical, 9)
        .overlay(alignment: .bottom) { Divider() }
    }

    private func numbers(_ tokens: Int64) -> some View {
        Text("\(tokens.formatted(.number.notation(.compactName))) · \(share(tokens).formatted(.percent.precision(.fractionLength(0))))")
            .font(.caption.monospacedDigit()).fixedSize()
            .help("\(tokens.formatted()) tokens; \(share(tokens).formatted(.percent)) of all recorded usage")
    }

    private var assignmentEditor: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Project name (optional)", text: $projectName)
            TextField("Topic, e.g. Development", text: $topic)
            HStack {
                Spacer()
                Button("Save") {
                    analytics.assign(keys: group.projectKeys, projectName: projectName, topic: topic)
                    editing = false
                }.controlSize(.small)
            }
        }.textFieldStyle(.roundedBorder)
    }

    private func shortThreadLabel(_ id: String) -> String {
        let parts = id.split(separator: ":")
        return "\(id.hasPrefix("codex:") ? "Codex" : "Claude Code") · \(String(parts.dropFirst().joined(separator: ":").prefix(12)))"
    }
}

private struct AnalyticsShareBar: View {
    let share: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3).fill(Color(nsColor: .quaternaryLabelColor))
                RoundedRectangle(cornerRadius: 3).fill(Color(nsColor: .secondaryLabelColor))
                    .frame(width: geometry.size.width * max(0, min(1, share)))
            }
        }
        .frame(height: 6).accessibilityHidden(true)
    }
}
