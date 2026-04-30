import AppKit
import Foundation
import TokenMonitorCore
import WebKit

enum SessionControllerError: LocalizedError {
    case controllerMissing(String)
    case refreshAlreadyInProgress
    case invalidPayload
    case emptyUsagePage

    var errorDescription: String? {
        switch self {
        case let .controllerMissing(service):
            return "Missing session controller for \(service)"
        case .refreshAlreadyInProgress:
            return "Refresh already in progress"
        case .invalidPayload:
            return "The usage page returned an unreadable payload"
        case .emptyUsagePage:
            return "The usage page returned no readable text"
        }
    }
}

@MainActor
final class ServiceSessionController: NSObject, WKNavigationDelegate, WKUIDelegate {
    private let service: ServiceKind
    private let parser: any UsageParsing
    private let dataStore: WKWebsiteDataStore
    private let diagnosticsStore: DiagnosticsStore
    private lazy var browserController: ServiceLoginWindowController = makeBrowserController()
    private lazy var backgroundWebView: WKWebView = makeBackgroundWebView()

    private var pendingContinuation: CheckedContinuation<ServiceSnapshot, Error>?
    private var currentLoadToken = UUID()
    private var extractionScheduled = false

    init(service: ServiceKind, diagnosticsStore: DiagnosticsStore) {
        self.service = service
        self.diagnosticsStore = diagnosticsStore
        switch service {
        case .claude:
            parser = ClaudeUsageParser()
        case .chatGPT:
            parser = ChatGPTUsageParser()
        }
        dataStore = WKWebsiteDataStore.default()
        super.init()
    }

    func refresh() async throws -> ServiceSnapshot {
        guard pendingContinuation == nil else {
            throw SessionControllerError.refreshAlreadyInProgress
        }

        currentLoadToken = UUID()
        extractionScheduled = false

        return try await withCheckedThrowingContinuation { continuation in
            pendingContinuation = continuation
            let request = URLRequest(
                url: service.usageURL,
                cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
                timeoutInterval: 60
            )
            backgroundWebView.load(request)
        }
    }

    func showLoginWindow(
        onAuthenticated: @escaping @MainActor () -> Void,
        onDismissed: @escaping @MainActor () -> Void
    ) {
        browserController.prepareForAuthentication(
            onAuthenticated: onAuthenticated,
            onDismissed: onDismissed
        )
        browserController.showWindowAndActivate()
    }

    private func handlePageFinishedLoading() {
        guard !extractionScheduled else {
            return
        }

        extractionScheduled = true
        let loadToken = currentLoadToken

        Task { @MainActor in
            await extractSnapshot(loadToken: loadToken)
        }
    }

    private func handleNavigationFailure(_ error: Error) {
        handleNavigationError(error)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard webView === backgroundWebView else {
            return
        }

        handlePageFinishedLoading()
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
    ) {
        guard webView === backgroundWebView else {
            decisionHandler(.cancel)
            return
        }

        if navigationAction.targetFrame == nil {
            recordBlockedNavigation(
                navigationAction.request.url,
                reason: "Blocked new-window navigation during automatic refresh"
            )
            decisionHandler(.cancel)
            return
        }

        guard allowsEmbeddedWebNavigation(navigationAction) else {
            recordBlockedNavigation(
                navigationAction.request.url,
                reason: "Blocked non-web navigation during automatic refresh"
            )
            decisionHandler(.cancel)
            if navigationAction.targetFrame?.isMainFrame != false {
                handlePageFinishedLoading()
            }
            return
        }

        decisionHandler(.allow)
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationResponse: WKNavigationResponse,
        decisionHandler: @escaping @MainActor @Sendable (WKNavigationResponsePolicy) -> Void
    ) {
        guard webView === backgroundWebView else {
            decisionHandler(.cancel)
            return
        }

        guard allowsEmbeddedWebNavigation(navigationResponse.response.url) else {
            recordBlockedNavigation(
                navigationResponse.response.url,
                reason: "Blocked non-web response during automatic refresh"
            )
            decisionHandler(.cancel)
            handlePageFinishedLoading()
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
        recordBlockedNavigation(
            navigationAction.request.url,
            reason: "Blocked popup during automatic refresh"
        )
        return nil
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        guard webView === backgroundWebView else {
            return
        }

        handleNavigationError(error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        guard webView === backgroundWebView else {
            return
        }

        handleNavigationError(error)
    }

    private func extractSnapshot(loadToken: UUID) async {
        let delays: [UInt64] = [500_000_000, 1_500_000_000, 3_000_000_000, 6_000_000_000, 10_000_000_000]
        var latestExtract: ServicePageExtract?

        for (index, delay) in delays.enumerated() {
            try? await Task.sleep(nanoseconds: delay)

            guard loadToken == currentLoadToken else {
                return
            }

            do {
                let extract = try await evaluateCurrentPage()
                latestExtract = extract
                if extract.isEmptyUsagePayload {
                    if index == delays.count - 1 {
                        writeDebugRecord(
                            from: extract,
                            outcome: .transportFailure,
                            message: "Usage page returned no readable text"
                        )
                        finishRefresh(with: .failure(SessionControllerError.emptyUsagePage))
                    }
                    continue
                }
                let snapshot = try parser.parse(extract: extract, now: Date())
                writeDebugRecord(from: extract, outcome: .success, message: nil)
                finishRefresh(with: .success(snapshot))
                return
            } catch let parseError as UsageParseError {
                switch parseError {
                case .authRequired:
                    if let latestExtract {
                        writeDebugRecord(from: latestExtract, outcome: .authRequired, message: String(describing: parseError))
                    }
                    finishRefresh(with: .failure(parseError))
                    return
                case .unsupportedLayout:
                    if index == delays.count - 1 {
                        if let latestExtract {
                            writeDebugRecord(from: latestExtract, outcome: .parseFailure, message: String(describing: parseError))
                        }
                        finishRefresh(with: .failure(parseError))
                    }
                }
            } catch {
                if index == delays.count - 1 {
                    if let latestExtract {
                        writeDebugRecord(from: latestExtract, outcome: .transportFailure, message: error.localizedDescription)
                    } else {
                        writeDebugRecord(
                            from: ServicePageExtract(
                                service: service,
                                pageTitle: backgroundWebView.title ?? "",
                                url: backgroundWebView.url?.absoluteString ?? service.usageURL.absoluteString,
                                bodyText: "",
                                segments: []
                            ),
                            outcome: .transportFailure,
                            message: error.localizedDescription
                        )
                    }
                    finishRefresh(with: .failure(error))
                }
            }
        }
    }

    private func evaluateCurrentPage() async throws -> ServicePageExtract {
        let payload = try await backgroundWebView.tm_evaluateJavaScript(extractionScript(for: service))

        guard let data = payload.data(using: .utf8) else {
            throw SessionControllerError.invalidPayload
        }

        return try JSONDecoder().decode(ServicePageExtract.self, from: data)
    }

    private func handleNavigationError(_ error: Error) {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled {
            return
        }
        if nsError.domain == WKError.errorDomain, nsError.code == 102 {
            handlePageFinishedLoading()
            return
        }

        finishRefresh(with: .failure(error))
    }

    private func finishRefresh(with result: Result<ServiceSnapshot, Error>) {
        extractionScheduled = false

        guard let continuation = pendingContinuation else {
            return
        }

        pendingContinuation = nil

        switch result {
        case let .success(snapshot):
            continuation.resume(returning: snapshot)
        case let .failure(error):
            continuation.resume(throwing: error)
        }
    }

    private func writeDebugRecord(from extract: ServicePageExtract, outcome: RefreshDebugRecord.Outcome, message: String?) {
        let preview = extract.bodyText
            .replacingOccurrences(of: "\r\n", with: "\n")
            .prefix(4000)

        diagnosticsStore.record(
            RefreshDebugRecord(
                timestamp: Date(),
                service: service,
                outcome: outcome,
                pageTitle: extract.pageTitle,
                url: extract.url,
                bodyPreview: String(preview),
                segments: Array(extract.segments.prefix(80)),
                message: message
            )
        )
    }

    private func recordBlockedNavigation(_ url: URL?, reason: String) {
        diagnosticsStore.record(
            RefreshDebugRecord(
                timestamp: Date(),
                service: service,
                outcome: .navigationBlocked,
                pageTitle: backgroundWebView.title ?? "",
                url: url?.absoluteString ?? "",
                bodyPreview: "",
                segments: [reason],
                message: reason
            )
        )
    }

    private func makeBrowserController() -> ServiceLoginWindowController {
        let controller = ServiceLoginWindowController(service: service, dataStore: dataStore)
        controller.onPageFinishedLoading = { [weak self] in
            guard let self, self.service == .chatGPT else {
                return
            }
            self.handlePageFinishedLoading()
        }
        controller.onNavigationFailure = { [weak self] error in
            guard let self, self.service == .chatGPT else {
                return
            }
            self.handleNavigationFailure(error)
        }
        return controller
    }

    private func makeBackgroundWebView() -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = dataStore
        configuration.defaultWebpagePreferences.preferredContentMode = .desktop
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false

        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1440, height: 2200), configuration: configuration)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        return webView
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
private extension WKWebView {
    func tm_evaluateJavaScript(_ script: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            evaluateJavaScript(script) { value, error in
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
}

private extension ServicePageExtract {
    var isEmptyUsagePayload: Bool {
        pageTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && segments.allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
}

private func extractionScript(for service: ServiceKind) -> String {
    switch service {
    case .claude:
        return """
        (() => {
          const textParts = (node, seen = new Set()) => {
            if (!node || seen.has(node)) return [];
            seen.add(node);
            const parts = [];
            if (node.nodeType === Node.TEXT_NODE) {
              const value = (node.nodeValue || '').trim();
              if (value) parts.push(value);
              return parts;
            }
            if (node.nodeType !== Node.ELEMENT_NODE && node.nodeType !== Node.DOCUMENT_NODE && node.nodeType !== Node.DOCUMENT_FRAGMENT_NODE) {
              return parts;
            }
            if (node.matches && node.matches('script, style, noscript, template')) {
              return parts;
            }
            const label = node.getAttribute ? (node.getAttribute('aria-label') || node.getAttribute('title') || node.getAttribute('placeholder')) : '';
            if (label && label.trim()) parts.push(label.trim());
            if (node.shadowRoot) parts.push(...textParts(node.shadowRoot, seen));
            for (const child of Array.from(node.childNodes || [])) {
              parts.push(...textParts(child, seen));
            }
            return parts;
          };
          const readableText = (root) => {
            if (!root) return "";
            const clone = root.cloneNode(true);
            clone.querySelectorAll('script, style, noscript, template').forEach(node => node.remove());
            const visible = clone.innerText || clone.textContent || "";
            return visible || Array.from(new Set(textParts(root))).join("\\n");
          };
          const roots = [document.body, document.documentElement].filter(Boolean);
          const bodyText = Array.from(new Set(roots.map(readableText).filter(Boolean))).join("\\n");
          const interesting = Array.from(document.querySelectorAll('main, main *, section, article, div, span, p, h1, h2, h3, button, [aria-label]'))
            .map(node => (node.innerText || node.textContent || node.getAttribute('aria-label') || '').trim())
            .filter(text => text.length > 0 && text.length < 320)
            .filter(text => /%\\s*(used|genutzt|verwendet|verbraucht)|Current session|Aktuelle Sitzung|All models|Alle Modelle|Sonnet only|Nur Sonnet|Sonnet|Extra usage|Zusätzliche Nutzung|Zusätzliche Verwendung|Monthly spend limit|Monatliches Ausgabenlimit|Current balance|Aktueller Kontostand|Guthaben|\\$\\s?\\d|€\\s?\\d|\\d[\\d.,]*\\s?€/i.test(text));
          return JSON.stringify({
            service: "\(service.rawValue)",
            pageTitle: document.title || "",
            url: location.href,
            bodyText,
            segments: Array.from(new Set(interesting)).slice(0, 200)
          });
        })();
        """

    case .chatGPT:
        return """
        (() => {
          const readableText = (root) => {
            if (!root) return "";
            const clone = root.cloneNode(true);
            clone.querySelectorAll('script, style, noscript, template').forEach(node => node.remove());
            return clone.innerText || clone.textContent || "";
          };
          const bodyText = readableText(document.body);
          const cardTexts = Array.from(document.querySelectorAll('main section, main article, main div'))
            .map(node => (node.innerText || node.textContent || '').trim())
            .filter(text => /usage limit|credits remaining|remaining|resets/i.test(text))
            .filter(text => text.length > 0 && text.length < 800);
          const interesting = Array.from(document.querySelectorAll('main, main *, section, article, div, span, button, h1, h2, h3'))
            .map(node => (node.innerText || node.textContent || '').trim())
            .filter(text => text.length > 0 && text.length < 320)
            .filter(text => /% remaining|% used|usage limit|credits remaining|codex|gpt-|weekly|5-hour|5 hour|resets/i.test(text));
          return JSON.stringify({
            service: "\(service.rawValue)",
            pageTitle: document.title || "",
            url: location.href,
            bodyText: [bodyText].concat(cardTexts).join("\\n"),
            segments: Array.from(new Set(interesting.concat(cardTexts))).slice(0, 240)
          });
        })();
        """
    }
}
