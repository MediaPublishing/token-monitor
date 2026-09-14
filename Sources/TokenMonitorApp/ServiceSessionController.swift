import AppKit
import Foundation
import TokenMonitorCore
import WebKit

enum SessionControllerError: LocalizedError {
    case controllerMissing(String)
    case refreshAlreadyInProgress
    case refreshTimedOut
    case invalidPayload
    case emptyUsagePage

    var errorDescription: String? {
        switch self {
        case let .controllerMissing(service):
            return "Missing session controller for \(service)"
        case .refreshAlreadyInProgress:
            return "Refresh already in progress"
        case .refreshTimedOut:
            return "Usage page refresh timed out"
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
    private var useAuthenticatedLoginPageForNextRefresh = false
    private var refreshTimeoutTask: Task<Void, Never>?

    init(service: ServiceKind, diagnosticsStore: DiagnosticsStore) {
        self.service = service
        self.diagnosticsStore = diagnosticsStore
        switch service {
        case .claude:
            parser = ClaudeUsageParser()
        case .chatGPT:
            parser = ChatGPTUsageParser()
        case .openCodeGo:
            parser = OpenCodeGoUsageParser()
        }
        dataStore = WKWebsiteDataStore.default()
        super.init()
    }

    func refresh() async throws -> ServiceSnapshot {
        guard pendingContinuation == nil else {
            throw SessionControllerError.refreshAlreadyInProgress
        }

        if service == .chatGPT, useAuthenticatedLoginPageForNextRefresh {
            let snapshot = try await snapshotFromAuthenticatedLoginPage()
            useAuthenticatedLoginPageForNextRefresh = false
            return snapshot
        }

        currentLoadToken = UUID()
        extractionScheduled = false

        return try await withCheckedThrowingContinuation { continuation in
            pendingContinuation = continuation
            scheduleRefreshTimeout(loadToken: currentLoadToken)
            let request = URLRequest(
                url: service.usageURL,
                cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
                timeoutInterval: 60
            )
            backgroundWebView.load(request)
        }
    }

    func cancelRefresh() {
        guard pendingContinuation != nil else {
            return
        }

        currentLoadToken = UUID()
        extractionScheduled = false
        backgroundWebView.stopLoading()
        finishRefresh(with: .failure(CancellationError()))
    }

    func showLoginWindow(
        replacingExistingSession: Bool = false,
        onAuthenticated: @escaping @MainActor () -> Void,
        onDismissed: @escaping @MainActor () -> Void
    ) {
        useAuthenticatedLoginPageForNextRefresh = false
        browserController.prepareForAuthentication(
            onAuthenticated: { [weak self] in
                if self?.service == .chatGPT {
                    self?.useAuthenticatedLoginPageForNextRefresh = true
                }
                onAuthenticated()
            },
            onDismissed: onDismissed
        )

        guard replacingExistingSession else {
            browserController.showWindowAndActivate()
            return
        }

        Task { @MainActor in
            await clearSession()
            browserController.showWindowAndActivate()
        }
    }

    func clearSession() async {
        useAuthenticatedLoginPageForNextRefresh = false
        cancelRefresh()
        backgroundWebView.stopLoading()
        browserController.prepareForSessionReset()

        let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        let records = await dataStore.tm_dataRecords(ofTypes: dataTypes)
        let serviceRecords = records.filter { record in
            websiteDataBelongsToService(record.displayName, service: service)
        }

        if !serviceRecords.isEmpty {
            await dataStore.tm_removeData(ofTypes: dataTypes, for: serviceRecords)
        }

        let cookies = await dataStore.httpCookieStore.tm_allCookies()
        for cookie in cookies where websiteDataBelongsToService(cookie.domain, service: service) {
            await dataStore.httpCookieStore.tm_delete(cookie)
        }
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

                if service == .openCodeGo,
                   let workspaceURL = extract.openCodeGoWorkspaceURL,
                   !isOpenCodeGoWorkspaceURL(URL(string: extract.url)) {
                    extractionScheduled = false
                    backgroundWebView.load(
                        URLRequest(
                            url: workspaceURL,
                            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
                            timeoutInterval: 60
                        )
                    )
                    return
                }

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
                if service == .chatGPT, snapshot.bankedResets == nil,
                   BankedResetParser.isLoading(extract), index < delays.count - 1 {
                    continue
                }
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

        return try decodePageExtract(payload)
    }

    private func snapshotFromAuthenticatedLoginPage() async throws -> ServiceSnapshot {
        let delays: [UInt64] = [0, 500_000_000, 1_500_000_000, 3_000_000_000]
        var latestExtract: ServicePageExtract?
        var latestError: Error = SessionControllerError.emptyUsagePage

        for (index, delay) in delays.enumerated() {
            if delay > 0 {
                try await Task.sleep(nanoseconds: delay)
            }
            try Task.checkCancellation()

            do {
                let payload = try await browserController.evaluateJavaScript(extractionScript(for: service))
                let extract = try decodePageExtract(payload)
                latestExtract = extract

                guard !extract.isEmptyUsagePayload else {
                    latestError = SessionControllerError.emptyUsagePage
                    continue
                }

                let snapshot = try parser.parse(extract: extract, now: Date())
                if service == .chatGPT, snapshot.bankedResets == nil,
                   BankedResetParser.isLoading(extract), index < delays.count - 1 {
                    continue
                }
                writeDebugRecord(from: extract, outcome: .success, message: nil)
                return snapshot
            } catch let parseError as UsageParseError {
                latestError = parseError
            } catch {
                latestError = error
            }
        }

        if let latestExtract {
            let outcome: RefreshDebugRecord.Outcome
            if let parseError = latestError as? UsageParseError {
                switch parseError {
                case .authRequired:
                    outcome = .authRequired
                case .unsupportedLayout:
                    outcome = .parseFailure
                }
            } else {
                outcome = .transportFailure
            }
            writeDebugRecord(from: latestExtract, outcome: outcome, message: latestError.localizedDescription)
        }

        throw latestError
    }

    private func decodePageExtract(_ payload: String) throws -> ServicePageExtract {
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
        refreshTimeoutTask?.cancel()
        refreshTimeoutTask = nil

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

    private func scheduleRefreshTimeout(loadToken: UUID) {
        refreshTimeoutTask?.cancel()
        refreshTimeoutTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 75_000_000_000)

            guard !Task.isCancelled,
                  let self,
                  loadToken == self.currentLoadToken,
                  self.pendingContinuation != nil else {
                return
            }

            self.backgroundWebView.stopLoading()
            self.writeDebugRecord(
                from: ServicePageExtract(
                    service: self.service,
                    pageTitle: self.backgroundWebView.title ?? "",
                    url: self.backgroundWebView.url?.absoluteString ?? self.service.usageURL.absoluteString,
                    bodyText: "",
                    segments: []
                ),
                outcome: .transportFailure,
                message: SessionControllerError.refreshTimedOut.localizedDescription
            )
            self.finishRefresh(with: .failure(SessionControllerError.refreshTimedOut))
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
        ServiceLoginWindowController(service: service, dataStore: dataStore)
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

private func websiteDataBelongsToService(_ value: String, service: ServiceKind) -> Bool {
    let normalized = value
        .lowercased()
        .trimmingCharacters(in: CharacterSet(charactersIn: "."))
    return serviceWebsiteHosts(service).contains { host in
        normalized == host || normalized.hasSuffix(".\(host)")
    }
}

private func serviceWebsiteHosts(_ service: ServiceKind) -> [String] {
    switch service {
    case .chatGPT:
        return ["chatgpt.com", "openai.com"]
    case .claude:
        return ["claude.ai", "anthropic.com"]
    case .openCodeGo:
        return ["opencode.ai"]
    }
}

private extension WKWebsiteDataStore {
    func tm_dataRecords(ofTypes dataTypes: Set<String>) async -> [WKWebsiteDataRecord] {
        await withCheckedContinuation { continuation in
            fetchDataRecords(ofTypes: dataTypes) { records in
                continuation.resume(returning: records)
            }
        }
    }

    func tm_removeData(ofTypes dataTypes: Set<String>, for records: [WKWebsiteDataRecord]) async {
        await withCheckedContinuation { continuation in
            removeData(ofTypes: dataTypes, for: records) {
                continuation.resume()
            }
        }
    }
}

private extension WKHTTPCookieStore {
    func tm_allCookies() async -> [HTTPCookie] {
        await withCheckedContinuation { continuation in
            getAllCookies { cookies in
                continuation.resume(returning: cookies)
            }
        }
    }

    func tm_delete(_ cookie: HTTPCookie) async {
        await withCheckedContinuation { continuation in
            delete(cookie) {
                continuation.resume()
            }
        }
    }
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

    var openCodeGoWorkspaceURL: URL? {
        guard service == .openCodeGo else {
            return nil
        }

        return links.compactMap(URL.init(string:)).first(where: isOpenCodeGoWorkspaceURL)
    }
}

private func isOpenCodeGoWorkspaceURL(_ url: URL?) -> Bool {
    guard let url,
          url.host == ServiceKind.openCodeGo.usageURL.host(),
          url.pathComponents.count >= 4,
          url.pathComponents[1] == "workspace",
          url.pathComponents.last == "go" else {
        return false
    }

    return true
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
            segments: Array.from(new Set(interesting)).slice(0, 200),
            links: []
          });
        })();
        """

    case .chatGPT:
        return """
        (() => {
          const visibleBody = document.body?.innerText || '';
          const resetHeading = /Usage limit resets|Banked resets|Gespeicherte Resets|Nutzungslimit-Zurücksetzungen/i.exec(visibleBody);
          const bankedResetText = resetHeading
            ? visibleBody.slice(resetHeading.index + resetHeading[0].length)
                .split(/\\n(?:Auto reload|Auto-reload credits|Usage breakdown|Credits usage history|Automatisches Aufladen)\\b/i)[0].trim()
            : null;
          const readableText = (root) => {
            if (!root) return "";
            const clone = root.cloneNode(true);
            clone.querySelectorAll('script, style, noscript, template').forEach(node => node.remove());
            return clone.innerText || clone.textContent || "";
          };
          const bodyText = readableText(document.body);
          const cardTexts = Array.from(document.querySelectorAll('main section, main article, main div'))
            .map(node => (node.innerText || node.textContent || '').trim())
            .filter(text => /usage limit|nutzungslimit|credits remaining|guthaben|remaining|verbleibend|resets|zurücksetz/i.test(text))
            .filter(text => text.length > 0 && text.length < 800);
          const interesting = Array.from(document.querySelectorAll('main, main *, section, article, div, span, button, h1, h2, h3'))
            .map(node => (node.innerText || node.textContent || '').trim())
            .filter(text => text.length > 0 && text.length < 320)
            .filter(text => /% remaining|% used|% verbleibend|% genutzt|usage limit|nutzungslimit|credits remaining|guthaben|codex|gpt-|weekly|wöchentlich|5-hour|5 hour|5-stunden|resets|zurücksetz/i.test(text));
          return JSON.stringify({
            service: "\(service.rawValue)",
            pageTitle: document.title || "",
            url: location.href,
            bodyText: [bodyText].concat(cardTexts).join("\\n"),
            segments: Array.from(new Set(interesting.concat(cardTexts))).slice(0, 240),
            links: [],
            bankedResetText,
            pageTimeZone: Intl.DateTimeFormat().resolvedOptions().timeZone
          });
        })();
        """

    case .openCodeGo:
        return """
        (() => {
          const readableText = (root) => {
            if (!root) return "";
            const clone = root.cloneNode(true);
            clone.querySelectorAll('script, style, noscript, template').forEach(node => node.remove());
            return clone.innerText || clone.textContent || "";
          };
          const bodyText = readableText(document.body);
          const usageItems = Array.from(document.querySelectorAll('[data-slot="usage-item"]'))
            .map(node => (node.innerText || node.textContent || '').trim())
            .filter(text => text.length > 0 && text.length < 800);
          const interesting = Array.from(document.querySelectorAll('main, main *, section, article, div, span, p, h1, h2, h3'))
            .map(node => (node.innerText || node.textContent || '').trim())
            .filter(text => text.length > 0 && text.length < 320)
            .filter(text => /%|(?:rolling|5[- ]hour)\\s+usage|weekly\\s+usage|monthly\\s+usage|resets?\\s+in/i.test(text));
          const links = Array.from(document.querySelectorAll('a[href]'))
            .map(node => {
              try { return new URL(node.getAttribute('href'), location.href).href; } catch (_) { return ''; }
            })
            .filter(url => /https:\\/\\/opencode\\.ai\\/workspace\\/[^/]+\\/go(?:[/?#]|$)/i.test(url));
          return JSON.stringify({
            service: "\(service.rawValue)",
            pageTitle: document.title || "",
            url: location.href,
            bodyText: [bodyText].concat(usageItems).join("\\n"),
            segments: Array.from(new Set(interesting.concat(usageItems))).slice(0, 240),
            links: Array.from(new Set(links)).slice(0, 20)
          });
        })();
        """
    }
}
