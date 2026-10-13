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
    private let readUsageButton = NSButton(title: "Read usage", target: nil, action: nil)
    private var didNotifyAuthenticated = false
    private var chatGPTLoginNavigation = ChatGPTLoginNavigation()
    private var currentNavigationToken = UUID()
    private var forcesGoogleAccountSelection = false
    private var didRewriteGoogleAuthorizationRequest = false
    private var chatGPTReadinessTask: Task<Void, Never>?
    private var openCodeGoReadinessTask: Task<Void, Never>?
    private var didTryOpenCodeConsole = false

    var onAuthenticated: (@MainActor () -> Void)?
    var onAuthenticationDismissed: (@MainActor () -> Void)?

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

    func showWindowAndActivate(usageURL: URL? = nil) {
        chatGPTLoginNavigation = ChatGPTLoginNavigation()
        didTryOpenCodeConsole = false
        openCodeGoReadinessTask?.cancel()
        showStatusBannerIfNeeded("Loading ChatGPT connection page...")
        loadUsagePage(url: service == .chatGPT ? ChatGPTLoginNavigation.connectionURL : usageURL)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func prepareForAuthentication(
        onAuthenticated callback: @escaping @MainActor () -> Void,
        onDismissed: @escaping @MainActor () -> Void
    ) {
        didNotifyAuthenticated = false
        chatGPTLoginNavigation = ChatGPTLoginNavigation()
        forcesGoogleAccountSelection = false
        didRewriteGoogleAuthorizationRequest = false
        invalidateReadinessChecks()
        onAuthenticated = callback
        onAuthenticationDismissed = onDismissed
    }

    func loadUsagePage(url: URL? = nil) {
        invalidateReadinessChecks()
        let request = URLRequest(url: url ?? service.usageURL, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 60)
        webView.load(request)
    }

    func prepareForSessionReset() {
        invalidateReadinessChecks()
        didNotifyAuthenticated = false
        chatGPTLoginNavigation = ChatGPTLoginNavigation()
        forcesGoogleAccountSelection = true
        didRewriteGoogleAuthorizationRequest = false
        webView.stopLoading()
        webView.loadHTMLString("", baseURL: nil)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let currentURL = webView.url?.absoluteString else {
            return
        }

        if service == .chatGPT {
            scheduleChatGPTAuthenticationCheck()
            return
        }

        if service == .openCodeGo {
            scheduleOpenCodeGoAuthenticationCheck(currentURL: currentURL)
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

        if navigationAction.targetFrame?.isMainFrame != false {
            invalidateReadinessChecks()
            chatGPTLoginNavigation.navigationStarted(at: navigationAction.request.url)
        }

        if let accountSelectionRequest = googleAccountSelectionRequest(from: navigationAction.request) {
            webView.load(accountSelectionRequest)
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

        invalidateReadinessChecks()
        chatGPTLoginNavigation.navigationStarted(at: url)

        if let accountSelectionRequest = googleAccountSelectionRequest(from: navigationAction.request) {
            webView.load(accountSelectionRequest)
            return nil
        }

        webView.load(URLRequest(url: url))
        return nil
    }

    private func finishLoadedPage(currentURL: String) {
        if isAuthenticatedUsagePageURL(currentURL) { notifyAuthenticated() }
    }

    private func notifyAuthenticated() {
        guard !didNotifyAuthenticated else { return }
        didNotifyAuthenticated = true
        forcesGoogleAccountSelection = false
        let callback = onAuthenticated
        onAuthenticated = nil
        onAuthenticationDismissed = nil
        callback?()
    }

    private func invalidateReadinessChecks() {
        currentNavigationToken = UUID()
        chatGPTReadinessTask?.cancel()
        openCodeGoReadinessTask?.cancel()
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        invalidateReadinessChecks()
    }

    private func scheduleChatGPTAuthenticationCheck() {
        chatGPTReadinessTask?.cancel()
        let navigationToken = currentNavigationToken
        chatGPTReadinessTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled, navigationToken == currentNavigationToken,
                      window?.isVisible == true, !didNotifyAuthenticated, onAuthenticated != nil else { return }
                let readiness = await readChatGPTPageReadiness()
                // JavaScript can finish after the user has already started another navigation.
                guard !Task.isCancelled, navigationToken == currentNavigationToken else { return }
                guard let readiness, webView.url?.absoluteString == readiness.url else { continue }
                if readiness.isBlank { continue }
                let page = ServicePageExtract(service: .chatGPT, pageTitle: readiness.title,
                                              url: readiness.url, bodyText: readiness.bodyText, segments: [])
                switch chatGPTLoginNavigation.action(for: page, hasAuthenticatedSession: readiness.hasAuthenticatedSession) {
                case .wait:
                    showStatusBannerIfNeeded("Finish signing in here. If you are already signed in, click Read usage.")
                    continue
                case .loadUsage:
                    showStatusBannerIfNeeded("ChatGPT is signed in. Loading usage limits...")
                    loadUsagePage()
                    return
                case .complete:
                    hideStatusBannerIfNeeded()
                    notifyAuthenticated()
                    return
                }
            }
        }
    }

    private func readChatGPTPageReadiness() async -> ChatGPTPageReadiness? {
        let payload = try? await evaluateAsyncJavaScript(
            """
              let hasAuthenticatedSession = false;
              if (location.origin === 'https://chatgpt.com') {
                const controller = new AbortController();
                const timeout = setTimeout(() => controller.abort(), 3000);
                try {
                  const response = await fetch('/api/auth/session', {
                    credentials: 'same-origin', cache: 'no-store', signal: controller.signal
                  });
                  if (response.ok) {
                    const session = await response.json();
                    hasAuthenticatedSession = typeof session?.user?.id === 'string' && session.user.id.length > 0;
                  }
                } catch (_) { } finally { clearTimeout(timeout); }
              }
              const visible = node => node && node.getClientRects().length > 0;
              const hasLoginControls = Array.from(document.querySelectorAll('input[type="email"], input[type="password"], input[autocomplete="username"]')).some(visible)
                || Array.from(document.querySelectorAll('button, a')).some(node => visible(node) && /^(?:log in|sign in|anmelden|melde dich an)$/i.test((node.innerText || '').trim()));
              const hasAccountMenu = Array.from(document.querySelectorAll('[data-testid="accounts-profile-button"], [data-testid="profile-button"], [data-testid="user-menu-button"]')).some(visible);
              hasAuthenticatedSession = location.origin === 'https://chatgpt.com'
                && !hasLoginControls && (hasAuthenticatedSession || hasAccountMenu);
              // Return only a boolean, never session tokens or account identifiers.
              return JSON.stringify({
                title: document.title || "", url: location.href,
                bodyText: ((document.body && (document.body.innerText || document.body.textContent)) || "").trim(),
                hasAuthenticatedSession
              });
            """
        )

        guard let payload, let data = payload.data(using: .utf8) else {
            return nil
        }

        return try? JSONDecoder().decode(ChatGPTPageReadiness.self, from: data)
    }

    private func scheduleOpenCodeGoAuthenticationCheck(currentURL: String) {
        openCodeGoReadinessTask?.cancel()
        let navigationToken = currentNavigationToken
        openCodeGoReadinessTask = Task { @MainActor in
            // Console is a SPA: completing login need not trigger didFinish.
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled, navigationToken == currentNavigationToken, window?.isVisible == true,
                      !didNotifyAuthenticated, onAuthenticated != nil else {
                    return
                }

                guard let readiness = await readOpenCodeGoPageReadiness() else {
                    continue
                }
                guard !Task.isCancelled, navigationToken == currentNavigationToken else { return }
                guard !readiness.hasLoginControls else { continue }

                if !didTryOpenCodeConsole, OpenCodeGoNavigation.isConsoleURL(readiness.url),
                   OpenCodeGoNavigation.workspaceURL(from: readiness.url) == nil,
                   readiness.workspaceURL == nil {
                    didTryOpenCodeConsole = true
                    loadUsagePage(url: OpenCodeGoNavigation.consoleUsageURL)
                    return
                }

                if let workspaceURL = OpenCodeGoNavigation.workspaceURL(from: readiness.workspaceURL),
                   OpenCodeGoNavigation.workspaceURL(from: readiness.url) == nil {
                    loadUsagePage(url: workspaceURL)
                    return
                }

                if readiness.isAuthenticated {
                    finishLoadedPage(currentURL: webView.url?.absoluteString ?? currentURL)
                    return
                }
            }
        }
    }

    private func readOpenCodeGoPageReadiness() async -> OpenCodeGoPageReadiness? {
        let payload = try? await evaluateJavaScript(
            """
            JSON.stringify({
              url: location.href,
              bodyText: ((document.body && (document.body.innerText || document.body.textContent)) || "").trim(),
              hasLoginControls: Array.from(document.querySelectorAll('input[type="email"], input[type="password"], input[autocomplete="username"]')).some(node => node.getClientRects().length > 0)
                || Array.from(document.querySelectorAll('button, a')).some(node => node.getClientRects().length > 0 && /^(?:log in|sign in|login|continue with google|continue with github|anmelden|mit google fortfahren)$/i.test((node.innerText || '').trim())),
              hasUsageLabels: ["Weekly Usage", "Monthly Usage", "Rolling Usage", "5-hour Usage", "5 hour Usage", "5-Stunden-Nutzung", "Wöchentliche Nutzung"].some(label => (document.body?.innerText || "").toLowerCase().includes(label.toLowerCase())),
              workspaceURL: Array.from(document.querySelectorAll('a[href]')).map(node => {
                try {
                  const url = new URL(node.getAttribute('href'), location.href);
                  return url.origin === 'https://opencode.ai' && /^\\/(?:(?:[a-z]{2}(?:-[a-z]{2,4})?\\/)?workspace\\/[^/]+|console\\/(?:org_|wrk_)[^/]+)\\/go\\/?$/i.test(url.pathname) ? url.href : null;
                } catch (_) { return null; }
              }).find(Boolean) || null
            })
            """
        )

        guard let payload, let data = payload.data(using: .utf8) else {
            return nil
        }

        return try? JSONDecoder().decode(OpenCodeGoPageReadiness.self, from: data)
    }

    private func isAuthenticatedUsagePageURL(_ currentURL: String) -> Bool {
        guard let url = URL(string: currentURL) else {
            return false
        }

        if service == .openCodeGo {
            guard url.host == ServiceKind.openCodeGo.usageURL.host() else {
                return false
            }

            return isOpenCodeGoWorkspaceURL(currentURL)
        }

        return currentURL.contains(service.usageURL.host() ?? "")
            && currentURL.contains(service.usageURL.path)
    }

    private func googleAccountSelectionRequest(from request: URLRequest) -> URLRequest? {
        guard forcesGoogleAccountSelection,
              !didRewriteGoogleAuthorizationRequest,
              let url = request.url,
              url.host()?.lowercased() == "accounts.google.com",
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }

        var queryItems = components.queryItems ?? []
        let isOAuthAuthorizationRequest = queryItems.contains { $0.name == "client_id" }
            && queryItems.contains { $0.name == "redirect_uri" }
        guard isOAuthAuthorizationRequest else {
            return nil
        }

        let promptItems = queryItems.filter { $0.name == "prompt" }
        let promptStrings = promptItems.compactMap { $0.value }
        let promptValues = promptStrings.flatMap { value in
            value.split(separator: " ").map { String($0) }
        }
        let existingPromptValues = promptValues.filter { value in
            value != "none" && value != "select_account"
        }

        queryItems.removeAll { item in
            ["prompt", "login_hint", "authuser"].contains(item.name)
        }
        queryItems.append(
            URLQueryItem(
                name: "prompt",
                value: (existingPromptValues + ["select_account"]).joined(separator: " ")
            )
        )
        components.queryItems = queryItems

        guard let accountSelectionURL = components.url else {
            return nil
        }

        didRewriteGoogleAuthorizationRequest = true
        var accountSelectionRequest = request
        accountSelectionRequest.url = accountSelectionURL
        return accountSelectionRequest
    }

    private func configureStatusBanner() {
        statusBanner.translatesAutoresizingMaskIntoConstraints = false
        statusBanner.wantsLayer = true
        statusBanner.layer?.backgroundColor = NSColor.systemYellow.withAlphaComponent(0.14).cgColor

        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        readUsageButton.target = self
        readUsageButton.action = #selector(readUsageAfterSignIn)
        readUsageButton.bezelStyle = .rounded
        readUsageButton.translatesAutoresizingMaskIntoConstraints = false
        readUsageButton.toolTip = "After signing in, open usage limits without clearing your session."

        statusBanner.addSubview(statusLabel)
        statusBanner.addSubview(readUsageButton)
        NSLayoutConstraint.activate([
            statusLabel.leadingAnchor.constraint(equalTo: statusBanner.leadingAnchor, constant: 14),
            statusLabel.trailingAnchor.constraint(equalTo: readUsageButton.leadingAnchor, constant: -12),
            statusLabel.topAnchor.constraint(equalTo: statusBanner.topAnchor, constant: 10),
            statusLabel.bottomAnchor.constraint(equalTo: statusBanner.bottomAnchor, constant: -10),
            readUsageButton.trailingAnchor.constraint(equalTo: statusBanner.trailingAnchor, constant: -14),
            readUsageButton.centerYAnchor.constraint(equalTo: statusBanner.centerYAnchor),
            statusBanner.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
    }

    @objc private func readUsageAfterSignIn() {
        showStatusBannerIfNeeded("Loading usage limits from your existing session...")
        loadUsagePage()
    }

    private func showStatusBannerIfNeeded(_ message: String) {
        guard service == .chatGPT else {
            return
        }

        guard statusLabel.stringValue != message || statusBanner.isHidden else { return }
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
        if isCancelledNavigation(error) { return }
        showStatusBannerIfNeeded("ChatGPT connection page could not be loaded. Try again without clearing your local session.")
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if isCancelledNavigation(error) { return }
        showStatusBannerIfNeeded("ChatGPT connection page could not be loaded. Try again without clearing your local session.")
    }

    private func isCancelledNavigation(_ error: Error) -> Bool {
        let error = error as NSError
        return error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled
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

    private func evaluateAsyncJavaScript(_ script: String) async throws -> String {
        let value = try await webView.callAsyncJavaScript(script, arguments: [:], in: nil, contentWorld: .page)
        guard let payload = value as? String else { throw SessionControllerError.invalidPayload }
        return payload
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        invalidateReadinessChecks()
        forcesGoogleAccountSelection = false
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
    let hasAuthenticatedSession: Bool

    var isBlank: Bool {
        let visibleText = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        return visibleText.isEmpty
    }
}

private struct OpenCodeGoPageReadiness: Decodable {
    let url: String
    let bodyText: String
    let hasUsageLabels: Bool
    let hasLoginControls: Bool
    let workspaceURL: String?

    var isAuthenticated: Bool {
        let hasWorkspaceUsageURL = isOpenCodeGoWorkspaceURL(url)
        let hasSubscriptionMessage = bodyText.localizedCaseInsensitiveContains("You are subscribed to OpenCode Go")
            || bodyText.localizedCaseInsensitiveContains("Du hast OpenCode Go abonniert")

        return hasWorkspaceUsageURL && (hasUsageLabels || hasSubscriptionMessage)
    }
}

private func isOpenCodeGoWorkspaceURL(_ value: String) -> Bool {
    OpenCodeGoNavigation.workspaceURL(from: value) != nil
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
