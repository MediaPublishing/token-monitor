import SwiftUI
import TokenMonitorCore

struct DashboardPopoverView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PopoverHeaderView()

            ForEach(model.dashboardState.services, id: \.service) { status in
                ServiceSectionView(status: status)
            }
        }
        .padding(10)
        .frame(width: AppDelegate.popoverWidth, alignment: .top)
        .fixedSize(horizontal: false, vertical: true)
        .background(Color(nsColor: .windowBackgroundColor))
    }

}

private struct ServiceSectionView: View {
    @EnvironmentObject private var model: AppModel

    let status: ServiceStatus

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 10) {
                Text(status.service.displayName)
                    .font(.headline)

                StateBadgeView(status: status.connectionStatus)

                Spacer()

                Button(buttonTitle) {
                    model.openLogin(for: status.service)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
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
        .padding(9)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
    }

    private var buttonTitle: String {
        switch status.connectionStatus {
        case .authRequired:
            return "Connect"
        case .healthy, .refreshing, .stale, .error:
            return "Reconnect"
        }
    }

    private func visibleMetrics(from snapshot: ServiceSnapshot) -> [UsageMetric] {
        snapshot.metrics.filter { metric in
            metric.key != "credits-remaining"
        }
    }
}

private struct StateBadgeView: View {
    let status: ServiceConnectionStatus

    var body: some View {
        Text(label)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
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
        VStack(alignment: .leading, spacing: 8) {
            Text(displayTitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Text(metric.valueText)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.primary)

            if metric.style == .progress, let progress = metric.progress {
                ProgressTrack(progress: progress, tint: tintColor)
            }

            if let subtitle = metric.subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Spacer(minLength: 0)
            }
        }
        .padding(7)
        .frame(maxWidth: .infinity, minHeight: 62, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
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
        case "weekly-all-models":
            return "All models"
        case "weekly-sonnet":
            return "Sonnet"
        case "claude-design":
            return "Design"
        case "extra-usage-spend":
            return "Extra usage"
        case "monthly-spend-limit":
            return "Monthly limit"
        case "current-balance":
            return "Balance"
        default:
            return metric.title
        }
    }

    private var tintColor: Color {
        if metric.valueText.localizedCaseInsensitiveContains("remaining") {
            guard let progress = metric.progress else {
                return .green
            }
            if progress >= 0.5 {
                return .green
            }
            if progress >= 0.25 {
                return .orange
            }
            return .red
        }
        if let progress = metric.progress, progress >= 0.9 {
            return .red
        }
        if let progress = metric.progress, progress >= 0.75 {
            return .orange
        }
        return .blue
    }
}

private struct ProgressTrack: View {
    let progress: Double
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.black.opacity(0.08))

                Capsule()
                    .fill(tint)
                    .frame(width: max(8, proxy.size.width * max(0, min(progress, 1))))
            }
        }
        .frame(height: 8)
    }
}
