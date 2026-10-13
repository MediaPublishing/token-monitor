import AppKit
import SwiftUI
import TokenMonitorCore

struct ProviderLogoView: View {
    @Environment(\.colorScheme) private var colorScheme
    let service: ServiceKind
    var size: CGFloat = 18
    @MainActor private static var images: [String: NSImage] = [:]

    @MainActor static func image(for service: ServiceKind, darkAppearance: Bool = false) -> NSImage? {
        let name: String
        switch service {
        case .chatGPT: name = "openai"
        case .claude: name = "claude"
        case .openCodeGo: name = darkAppearance ? "opencode-dark" : "opencode"
        }
        if let cached = images[name] { return cached }
        guard let url = Bundle.main.url(forResource: name, withExtension: "pdf", subdirectory: "ProviderLogos"),
              let image = NSImage(contentsOf: url) else { return nil }
        image.isTemplate = service == .chatGPT
        images[name] = image
        return image
    }

    var body: some View {
        Group {
            if let image = Self.image(for: service, darkAppearance: colorScheme == .dark) {
                NativeProviderLogo(image: image, size: size)
            } else {
                Image(systemName: "questionmark.square").resizable().scaledToFit()
            }
        }
        .frame(width: size, height: size)
        .help(service.displayName)
        .accessibilityLabel(service.displayName)
    }
}

private struct NativeProviderLogo: NSViewRepresentable {
    let image: NSImage
    let size: CGFloat

    func makeNSView(context: Context) -> NSImageView {
        let view = NSImageView()
        view.imageScaling = .scaleProportionallyUpOrDown
        return view
    }

    func updateNSView(_ view: NSImageView, context: Context) {
        if view.image !== image { view.image = image }
        view.contentTintColor = image.isTemplate ? .labelColor : nil
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSImageView, context: Context) -> CGSize? {
        CGSize(width: size, height: size)
    }
}
