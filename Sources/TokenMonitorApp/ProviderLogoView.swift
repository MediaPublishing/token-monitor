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
        guard let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "ProviderLogos"),
              let image = NSImage(contentsOf: url) else { return nil }
        images[name] = image
        return image
    }

    var body: some View {
        Group {
            if let image = Self.image(for: service, darkAppearance: colorScheme == .dark) {
                Image(nsImage: image)
                    .resizable()
                    .renderingMode(service == .chatGPT ? .template : .original)
                    .scaledToFit()
            } else {
                Image(systemName: "questionmark.square").resizable().scaledToFit()
            }
        }
        .frame(width: size, height: size)
        .help(service.displayName)
        .accessibilityLabel(service.displayName)
    }
}
