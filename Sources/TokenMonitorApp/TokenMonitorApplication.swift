import AppKit

@main
@MainActor
struct TokenMonitorApplication {
    private static let delegate = AppDelegate()

    static func main() {
        let application = NSApplication.shared
        application.delegate = delegate
        application.finishLaunching()
        application.run()
    }
}
