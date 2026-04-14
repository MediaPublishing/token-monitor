import AppKit
import Foundation
import TokenMonitorCore
import WebKit

@MainActor
final class ServiceLoginWindowController: NSWindowController, NSWindowDelegate, WKNavigationDelegate, WKUIDelegate {
    private let service: ServiceKind
    private let dataStore: WKWebsiteDataStore
    private let webView: WKWebView
    private let statusBanner = NSView()
    private let statusLabel = NSTextField(wrappingLabelWithString: "")
    private var didNotifyAuthenticated = false
    private var didAutoResetBlankChatGPTPage = false
    private var blankPageCheckTask: Task<Void, Never>?

    var onAuthenticated: (@MainActor () -> Void)?
    var onAuthenticationDismissed: (@MainActor () -> Void)?
    var onPageFinishedLoading: (@MainActor () -> Void)?
    var onNavigationFailure: (@MainActor (Error) -> Void)?

    init(service: ServiceKind, dataStore: WKWebsiteDataStore, onAuthenticated: (@MainActor () -> Void)? = nil) {
        self.service = service
        self.dataStore = dataStore
        self.onAuthenticated = onAuthenticated

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = dataStore
        configuration.defaultWebpagePreferences.preferredContentMode = .desktop
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false

        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1180, height: 840), configuration: configuration)
        webView.navigationDelegate = nil
        webView.uiDelegate = nil

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

        if service == .chatGPT {
            configureStatusBanner()
            stackView.insertArrangedSubview(statusBanner, at: 0)
            statusBanner.isHidden = true
        }

        window.delegate = self
        webView.navigationDelegate = self
        webView.uiDelegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showWindowAndActivate() {
        didAutoResetBlankChatGPTPage = false
        showStatusBannerIfNeeded("Loading ChatGPT connection page...")
        loadUsagePage()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func prepareForAuthentication(
        onAuthenticated callback: @escaping @MainActor () -> Void,
        onDismissed: @escaping @MainActor () -> Void
    ) {
        didNotifyAuthenticated = false
        didAutoResetBlankChatGPTPage = false
        onAuthenticated = callback
        onAuthenticationDismissed = onDismissed
    }

    func loadUsagePage() {
        blankPageCheckTask?.cancel()
        let request = URLRequest(url: service.usageURL, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 60)
        webView.load(request)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let currentURL = webView.url?.absoluteString else {
            onPageFinishedLoading?()
            return
        }

        if service == .chatGPT {
            scheduleChatGPTBlankPageCheck(currentURL: currentURL)
            return
        }

        finishLoadedPage(currentURL: currentURL)
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
    ) {
        guard allowsEmbeddedWebNavigation(navigationAction) else {
            decisionHandler(.cancel)
            return
        }

        if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
            webView.load(URLRequest(url: url))
            decisionHandler(.cancel)
            return
        }

        decisionHandler(.allow)
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationResponse: WKNavigationResponse,
        decisionHandler: @escaping @MainActor @Sendable (WKNavigationResponsePolicy) -> Void
    ) {
        guard allowsEmbeddedWebNavigation(navigationResponse.response.url) else {
            decisionHandler(.cancel)
            return
        }

        decisionHandler(.allow)
    }

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        guard allowsEmbeddedWebNavigation(navigationAction), let url = navigationAction.request.url else {
            return nil
        }

        webView.load(URLRequest(url: url))
        return nil
    }

    private func finishLoadedPage(currentURL: String) {
        if currentURL.contains(service.usageURL.host() ?? ""),
           currentURL.contains(service.usageURL.path),
           !didNotifyAuthenticated {
            didNotifyAuthenticated = true
            let callback = onAuthenticated
            onAuthenticated = nil
            onAuthenticationDismissed = nil
            callback?()
        }

        onPageFinishedLoading?()
    }

    private func scheduleChatGPTBlankPageCheck(currentURL: String) {
        blankPageCheckTask?.cancel()
        blankPageCheckTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 4_000_000_000)

            guard !Task.isCancelled else {
                return
            }

            guard let readiness = await readChatGPTPageReadiness() else {
                showStatusBannerIfNeeded("ChatGPT did not return a readable page. Resetting the local session and retrying...")
                resetLocalWebSessionAndReload()
                return
            }

            if readiness.isBlank {
                if !didAutoResetBlankChatGPTPage {
                    didAutoResetBlankChatGPTPage = true
                    showStatusBannerIfNeeded("ChatGPT returned an empty connection page. Resetting the local Token Monitor session and retrying...")
                    resetLocalWebSessionAndReload()
                    return
                }

                showStatusBannerIfNeeded("ChatGPT still returned an empty page after a local session reset. Token Monitor will mark this reconnect as failed instead of showing Healthy.")
            } else {
                hideStatusBannerIfNeeded()
            }

            finishLoadedPage(currentURL: currentURL)
        }
    }

    private func readChatGPTPageReadiness() async -> ChatGPTPageReadiness? {
        let payload = try? await evaluateJavaScript(
            """
            JSON.stringify({
              title: document.title || "",
              url: location.href,
              bodyText: ((document.body && (document.body.innerText || document.body.textContent)) || "").trim(),
              elementCount: document.body ? document.body.querySelectorAll("*").length : 0
            })
            """
        )

        guard let payload, let data = payload.data(using: .utf8) else {
            return nil
        }

        return try? JSONDecoder().decode(ChatGPTPageReadiness.self, from: data)
    }

    private func resetLocalWebSessionAndReload() {
        blankPageCheckTask?.cancel()
        let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        dataStore.removeData(ofTypes: dataTypes, modifiedSince: .distantPast) { [weak self] in
            Task { @MainActor in
                self?.loadUsagePage()
            }
        }
    }

    private func configureStatusBanner() {
        statusBanner.translatesAutoresizingMaskIntoConstraints = false
        statusBanner.wantsLayer = true
        statusBanner.layer?.backgroundColor = NSColor.systemYellow.withAlphaComponent(0.14).cgColor

        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        statusBanner.addSubview(statusLabel)
        NSLayoutConstraint.activate([
            statusLabel.leadingAnchor.constraint(equalTo: statusBanner.leadingAnchor, constant: 14),
            statusLabel.trailingAnchor.constraint(equalTo: statusBanner.trailingAnchor, constant: -14),
            statusLabel.topAnchor.constraint(equalTo: statusBanner.topAnchor, constant: 10),
            statusLabel.bottomAnchor.constraint(equalTo: statusBanner.bottomAnchor, constant: -10),
            statusBanner.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
    }

    private func showStatusBannerIfNeeded(_ message: String) {
        guard service == .chatGPT else {
            return
        }

        statusLabel.stringValue = message
        statusBanner.isHidden = false
    }

    private func hideStatusBannerIfNeeded() {
        guard service == .chatGPT else {
            return
        }

        statusBanner.isHidden = true
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
        blankPageCheckTask?.cancel()
        sender.orderOut(nil)
        let dismissCallback = onAuthenticationDismissed
        onAuthenticationDismissed = nil
        dismissCallback?()
        return false
    }
}

private struct ChatGPTPageReadiness: Decodable {
    let title: String
    let url: String
    let bodyText: String
    let elementCount: Int

    var isBlank: Bool {
        let visibleText = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        return visibleText.isEmpty
    }
}

@MainActor
private func allowsEmbeddedWebNavigation(_ navigationAction: WKNavigationAction) -> Bool {
    allowsEmbeddedWebNavigation(navigationAction.request.url)
}

private func allowsEmbeddedWebNavigation(_ url: URL?) -> Bool {
    guard let scheme = url?.scheme?.lowercased() else {
        return false
    }

    return ["about", "http", "https"].contains(scheme)
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
