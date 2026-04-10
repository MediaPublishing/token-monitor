import AppKit
import Foundation
import TokenMonitorCore
import WebKit

@MainActor
final class ServiceLoginWindowController: NSWindowController, NSWindowDelegate, WKNavigationDelegate {
    private let service: ServiceKind
    private let webView: WKWebView
    private var didNotifyAuthenticated = false
    private var isBackgroundPresented = false

    var onAuthenticated: (@MainActor () -> Void)?
    var onPageFinishedLoading: (@MainActor () -> Void)?
    var onNavigationFailure: (@MainActor (Error) -> Void)?

    init(service: ServiceKind, dataStore: WKWebsiteDataStore, onAuthenticated: (@MainActor () -> Void)? = nil) {
        self.service = service
        self.onAuthenticated = onAuthenticated

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = dataStore
        configuration.defaultWebpagePreferences.preferredContentMode = .desktop

        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1180, height: 840), configuration: configuration)
        webView.navigationDelegate = nil

        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 1180, height: 840))
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.spacing = 0
        stackView.translatesAutoresizingMaskIntoConstraints = false

        if service == .claude {
            stackView.addArrangedSubview(makeClaudeHintBanner())
        }

        stackView.addArrangedSubview(webView)
        containerView.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: containerView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1180, height: 840),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Connect \(service.displayName)"
        window.center()
        window.contentView = containerView

        super.init(window: window)

        window.delegate = self
        webView.navigationDelegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showWindowAndActivate() {
        endBackgroundPresentationIfNeeded()
        loadUsagePage()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func prepareForAuthentication(_ callback: @escaping @MainActor () -> Void) {
        didNotifyAuthenticated = false
        onAuthenticated = callback
    }

    func loadUsagePage() {
        let request = URLRequest(url: service.usageURL, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 60)
        webView.load(request)
    }

    func beginBackgroundRefreshPresentationIfNeeded() {
        guard let window, !window.isVisible else {
            return
        }

        isBackgroundPresented = true
        window.setFrame(NSRect(x: 24, y: 24, width: 1180, height: 840), display: false)
        window.alphaValue = 0.01
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.level = .floating
        window.orderFrontRegardless()
    }

    func endBackgroundPresentationIfNeeded() {
        guard isBackgroundPresented, let window else {
            return
        }

        isBackgroundPresented = false
        window.orderOut(nil)
        window.alphaValue = 1
        window.ignoresMouseEvents = false
        window.level = .normal
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let currentURL = webView.url?.absoluteString else {
            onPageFinishedLoading?()
            return
        }

        if currentURL.contains(service.usageURL.host() ?? ""),
           currentURL.contains(service.usageURL.path),
           !didNotifyAuthenticated {
            didNotifyAuthenticated = true
            let callback = onAuthenticated
            onAuthenticated = nil
            callback?()
        }

        onPageFinishedLoading?()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        onNavigationFailure?(error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        onNavigationFailure?(error)
    }

    func currentPageTitle() -> String {
        webView.title ?? ""
    }

    func currentPageURLString() -> String {
        webView.url?.absoluteString ?? service.usageURL.absoluteString
    }

    func evaluateJavaScript(_ script: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            webView.evaluateJavaScript(script) { value, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                if let value = value as? String {
                    continuation.resume(returning: value)
                } else {
                    continuation.resume(throwing: SessionControllerError.invalidPayload)
                }
            }
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        endBackgroundPresentationIfNeeded()
        sender.orderOut(nil)
        return false
    }
}

@MainActor
private func makeClaudeHintBanner() -> NSView {
    let container = NSView()
    container.translatesAutoresizingMaskIntoConstraints = false

    let label = NSTextField(wrappingLabelWithString: "Claude sign-in hint: if “Continue with Google” throws an error here, use “Continue with email” and enter the same Gmail address instead.")
    label.font = .systemFont(ofSize: 12)
    label.textColor = .secondaryLabelColor
    label.translatesAutoresizingMaskIntoConstraints = false

    container.addSubview(label)
    NSLayoutConstraint.activate([
        label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
        label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),
        label.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
        label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10),
        container.heightAnchor.constraint(greaterThanOrEqualToConstant: 48)
    ])

    return container
}
