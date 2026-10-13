import SwiftUI
import TokenMonitorCore

private enum PopoverMeasuredPart: Hashable {
    case header
    case content(PopoverScreen)
    case footer
}

private struct PopoverMeasurementsKey: PreferenceKey {
    static let defaultValue: [PopoverMeasuredPart: CGFloat] = [:]

    static func reduce(value: inout [PopoverMeasuredPart: CGFloat], nextValue: () -> [PopoverMeasuredPart: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private extension View {
    func measurePopoverPart(_ part: PopoverMeasuredPart) -> some View {
        background {
            GeometryReader { geometry in
                Color.clear.preference(key: PopoverMeasurementsKey.self, value: [part: geometry.size.height])
            }
        }
    }
}

struct PopoverRootView: View {
    @EnvironmentObject private var model: AppModel
    var onSizeChange: (PopoverScreen, CGSize) -> Void = { _, _ in }

    var body: some View {
        PopoverContentView(model: model, analytics: model.analytics, onSizeChange: onSizeChange)
    }
}

private struct PopoverContentView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var analytics: ProjectAnalyticsModel
    @State private var measurements: [PopoverMeasuredPart: CGFloat] = [:]
    @State private var scrollTargets: [PopoverScreen: String] = [:]
    let onSizeChange: (PopoverScreen, CGSize) -> Void

    private var layout: PopoverLayout {
        PopoverLayout(
            header: Double(measurements[.header] ?? 32),
            content: Double(measurements[.content(model.popoverScreen)] ?? 120),
            footer: model.popoverScreen == .analytics ? Double(measurements[.footer] ?? 16) : 0,
            spacing: model.popoverScreen == .analytics ? 40 : 30,
            maximumHeight: Double(model.popoverMaximumHeight)
        )
    }

    private var scrollPosition: Binding<String?> {
        let screen = model.popoverScreen
        return Binding(get: { scrollTargets[screen] }, set: { scrollTargets[screen] = $0 })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PopoverHeaderView(analytics: analytics)
                .measurePopoverPart(.header)

            ScrollView {
                content
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .fixedSize(horizontal: false, vertical: true)
                    .measurePopoverPart(.content(model.popoverScreen))
            }
            .scrollPosition(id: scrollPosition, anchor: .top)
            .scrollDisabled(!layout.scrolls)
            .scrollIndicators(layout.scrolls ? .automatic : .hidden)
            .frame(height: CGFloat(layout.contentHeight))

            if model.popoverScreen == .analytics {
                AnalyticsCoverageFooter(analytics: analytics)
                    .fixedSize(horizontal: false, vertical: true)
                    .measurePopoverPart(.footer)
            }
        }
        .padding(10)
        .frame(width: AppDelegate.popoverWidth, height: CGFloat(layout.height), alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
        .onPreferenceChange(PopoverMeasurementsKey.self) { values in
            measurements.merge(values, uniquingKeysWith: { _, new in new })
        }
        .onChange(of: layout.height, initial: true) { _, height in
            let screen = model.popoverScreen
            DispatchQueue.main.async {
                onSizeChange(screen, CGSize(width: AppDelegate.popoverWidth, height: height))
            }
        }
    }

    @ViewBuilder private var content: some View {
        switch model.popoverScreen {
        case .dashboard: DashboardPopoverView()
        case .analytics: ProjectAnalyticsView(analytics: analytics)
        case .settings: SettingsView(compact: true, analytics: analytics)
        }
    }
}
