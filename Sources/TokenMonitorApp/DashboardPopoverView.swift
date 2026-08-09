import SwiftUI
import TokenMonitorCore

struct DashboardPopoverView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PopoverHeaderView()

            ForEach(model.dashboardServices, id: \.service) { status in
                ServiceSectionView(status: status)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(width: AppDelegate.popoverWidth, height: model.desiredPopoverHeight(), alignment: .top)
        .background(Color(nsColor: .windowBackgroundColor))
    }

}

private struct ServiceSectionView: View {
    @EnvironmentObject private var model: AppModel

    let status: ServiceStatus

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 8),
        count: 3
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 8) {
                Text(status.service.displayName)
                    .font(.headline)

                StateBadgeView(status: status.connectionStatus)

                Spacer()

                Button {
                    refreshOrConnect()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.bordered)
                .clipShape(Circle())
                .help(status.connectionStatus == .authRequired ? "Connect" : "Refresh")
            }

            Text(model.stateDescription(for: status))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if case .refreshing = status.refreshState {
                ProgressView()
                    .controlSize(.small)
            }

            if let snapshot = status.snapshot, !visibleMetrics(from: snapshot).isEmpty {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                    ForEach(visibleMetrics(from: snapshot)) { metric in
                        MetricCardView(metric: metric)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("No snapshot available yet")
                        .font(.subheadline.weight(.medium))
                    Text("Sign in, then refresh.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
            }
        }
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private func refreshOrConnect() {
        if status.connectionStatus == .authRequired {
            model.openLogin(for: status.service)
        } else {
            model.refresh(status.service, trigger: .manual, force: true)
        }
    }

    private func visibleMetrics(from snapshot: ServiceSnapshot) -> [UsageMetric] {
        var metrics = snapshot.metrics.filter { metric in
            guard metric.key != "credits-remaining" else {
                return false
            }

            if metric.key == "spark-weekly-limit" {
                return false
            }

            guard model.showUsageDetails || snapshot.service != .claude else {
                return !["extra-usage-spend", "monthly-spend-limit", "current-balance"].contains(metric.key)
            }

            return true
        }

        guard snapshot.service == .claude,
              let limitIndex = metrics.firstIndex(where: { $0.key == "monthly-spend-limit" }),
              let balanceIndex = metrics.firstIndex(where: { $0.key == "current-balance" }) else {
            return metrics
        }

        let limit = metrics[limitIndex]
        let balance = metrics[balanceIndex]
        let combined = UsageMetric(
            key: "monthly-limit-balance",
            title: "Monthly limit / Balance",
            valueText: "\(compactMoneyText(limit.valueText)) / \(compactMoneyText(balance.valueText))",
            subtitle: nil,
            progress: nil,
            style: .stat
        )

        metrics[limitIndex] = combined
        metrics.remove(at: balanceIndex)
        return metrics
    }

    private func compactMoneyText(_ value: String) -> String {
        var compact = value
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: "€", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if compact.hasSuffix(".00") || compact.hasSuffix(",00") {
            compact.removeLast(3)
        }

        return compact.isEmpty ? value : compact
    }
}

private struct StateBadgeView: View {
    let status: ServiceConnectionStatus

    var body: some View {
        Text(label)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
    }

    private var label: String {
        switch status {
        case .healthy:
            return "Healthy"
        case .refreshing:
            return "Refreshing"
        case .stale:
            return "Stale"
        case .authRequired:
            return "Auth Required"
        case .error:
            return "Error"
        }
    }

    private var color: Color {
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

private struct MetricCardView: View {
    let metric: UsageMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(displayTitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Text(displayValueText)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.primary)

            if metric.style == .progress, let progress = availableProgress {
                ProgressTrack(progress: progress, tint: tintColor)
            }

            if let subtitle = metric.displaySubtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Spacer(minLength: 0)
            }
        }
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .topLeading)
    }

    private var displayTitle: String {
        switch metric.key {
        case "five-hour-limit":
            return "5 hour"
        case "weekly-limit":
            return "Weekly"
        case "spark-five-hour-limit":
            return "Codex 5 hour"
        case "spark-weekly-limit":
            return "Codex weekly"
        case "credits-remaining":
            return "Credits"
        case "current-session":
            return "Session"
        case "rolling-usage":
            return "Rolling"
        case "monthly-usage":
            return "Monthly"
        case "weekly-usage":
            return "Weekly"
        case "weekly-all-models":
            return "All models"
        case "weekly-sonnet":
            return "Sonnet"
        case "claude-design":
            return "Design"
        case "extra-usage-spend":
            return "Extra usage"
        case "monthly-limit-balance":
            return "Monthly limit / Balance"
        case "monthly-spend-limit":
            return "Monthly limit"
        case "current-balance":
            return "Balance"
        default:
            return metric.title
        }
    }

    private var tintColor: Color {
        guard let progress = availableProgress else {
            return .blue
        }

        if progress >= 0.75 {
            return Color(nsColor: .systemGreen)
        }
        if progress >= 0.5 {
            return Color(nsColor: .systemMint)
        }
        if progress >= 0.25 {
            return Color(nsColor: .systemOrange)
        }
        return Color(nsColor: .systemRed)
    }

    private var availableProgress: Double? {
        guard let progress = metric.progress else {
            return nil
        }

        let clamped = max(0, min(progress, 1))
        if isUsedMetric {
            return 1 - clamped
        }

        return clamped
    }

    private var displayValueText: String {
        guard isUsedPercentageMetric, let progress = metric.progress else {
            return metric.valueText
        }

        let remaining = max(0, min(1, 1 - progress))
        return "\(Int((remaining * 100).rounded()))% remaining"
    }

    private var isUsedPercentageMetric: Bool {
        metric.valueText.contains("%") && isUsedMetric
    }

    private var isUsedMetric: Bool {
        metric.valueText.localizedCaseInsensitiveContains("used")
            || metric.valueText.localizedCaseInsensitiveContains("spent")
            || metric.valueText.localizedCaseInsensitiveContains("genutzt")
            || metric.valueText.localizedCaseInsensitiveContains("verwendet")
            || metric.valueText.localizedCaseInsensitiveContains("verbraucht")
            || metric.valueText.localizedCaseInsensitiveContains("ausgegeben")
    }

}

private struct ProgressTrack: View {
    let progress: Double
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            let clamped = max(0, min(progress, 1))
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.black.opacity(0.08))

                Capsule()
                    .fill(tint)
                    .frame(width: max(8, proxy.size.width * clamped))
            }
        }
        .frame(height: 10)
    }
}
