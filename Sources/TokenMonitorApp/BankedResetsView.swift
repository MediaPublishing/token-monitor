import SwiftUI
import TokenMonitorCore

struct BankedResetsView: View {
    let inventory: BankedResetInventory?
    let snapshotDate: Date
    let openUsage: () -> Void
    @State private var showsDetails = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let groups = inventory?.availableGroups(at: context.date) ?? []
            let count = groups.reduce(0) { $0 + $1.count }
            let nextExpiry = groups.compactMap(\.expiresAt).min()
            let stale = inventory.map { snapshotDate.timeIntervalSince($0.capturedAt) > 1 } ?? false
            let urgent = nextExpiry.map { $0.timeIntervalSince(context.date) <= ResetReminderPlanner.leadTime } ?? false
            Button { showsDetails.toggle() } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.counterclockwise.circle")
                        .foregroundStyle(urgent ? Color.orange : .secondary)
                    Text(inventory == nil ? "Banked resets unavailable" : "\(stale ? "Last seen: " : "")\(count) banked \(count == 1 ? "reset" : "resets")")
                        .font(.caption.weight(.medium))
                    Spacer(minLength: 6)
                    if let nextExpiry {
                        Text("Expires \(Self.dateText(nextExpiry))")
                            .foregroundStyle(urgent ? Color.orange : .secondary)
                    } else if count > 0 {
                        Text("Expiry unavailable").foregroundStyle(.secondary)
                    }
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .font(.caption2)
                .frame(height: 26)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Saved usage-limit resets. No reset will be used automatically.")
            .popover(isPresented: $showsDetails, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Banked resets").font(.headline)
                    if let inventory {
                        Text("Checked \(Self.dateText(inventory.capturedAt))")
                            .font(.caption).foregroundStyle(.secondary)
                        if stale {
                            Text("The latest refresh could not confirm these resets.")
                                .font(.caption).foregroundStyle(.orange)
                        }
                        if groups.isEmpty {
                            Text("No available banked resets.").font(.subheadline)
                        } else {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 12) {
                                    ForEach(groups) { group in
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text("\(group.count) \(group.title.lowercased())\(group.count == 1 ? "" : "s")")
                                                .font(.subheadline.weight(.medium))
                                            Text(group.expiresAt.map { "Expires \(Self.dateText($0))" } ?? "Expiry unavailable")
                                                .font(.caption).foregroundStyle(.secondary)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                            }
                            .frame(height: min(CGFloat(groups.count) * 47, 220))
                        }
                    } else {
                        Text("ChatGPT has not returned readable reset details yet. Refresh or check your usage page.")
                            .font(.subheadline)
                    }
                    Divider()
                    Button("Review in ChatGPT") {
                        showsDetails = false
                        openUsage()
                    }
                    .controlSize(.small)
                }
                .padding(16)
                .frame(width: 320, alignment: .leading)
            }
        }
    }

    private static func dateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d, HH:mm"
        return formatter.string(from: date)
    }
}

struct ResetReminderSettingsView: View {
    @ObservedObject var reminders: ResetReminderController

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Reset reminders").font(.subheadline.weight(.semibold))
                Text(reminders.statusText)
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Toggle("Reset reminders", isOn: Binding(get: { reminders.enabled }, set: { reminders.setEnabled($0) }))
                .labelsHidden().toggleStyle(.switch).controlSize(.small).fixedSize()
        }
    }
}
