import AppKit
import Foundation
import TokenMonitorCore
import WebKit

enum SessionControllerError: LocalizedError {
    case controllerMissing(String)
    case refreshAlreadyInProgress
    case invalidPayload

    var errorDescription: String? {
        switch self {
        case let .controllerMissing(service):
            return "Missing session controller for \(service)"
        case .refreshAlreadyInProgress:
            return "Refresh already in progress"
        case .invalidPayload:
            return "The usage page returned an unreadable payload"
        }
    }
}

@MainActor
final class ServiceSessionController: NSObject, WKNavigationDelegate {
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
        dataStore = WKWebsiteDataStore(forIdentifier: service.dataStoreIdentifier)
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
            if service == .chatGPT {
                browserController.beginBackgroundRefreshPresentationIfNeeded()
                browserController.loadUsagePage()
            } else {
                let request = URLRequest(
                    url: service.usageURL,
                    cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
                    timeoutInterval: 60
                )
                backgroundWebView.load(request)
            }
        }
    }

    func showLoginWindow(onAuthenticated: @escaping @MainActor () -> Void) {
        browserController.prepareForAuthentication(onAuthenticated)
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
        let delays: [UInt64] = [350_000_000, 900_000_000, 1_700_000_000]
        var latestExtract: ServicePageExtract?

        for (index, delay) in delays.enumerated() {
            try? await Task.sleep(nanoseconds: delay)

            guard loadToken == currentLoadToken else {
                return
            }

            do {
                let extract = try await evaluateCurrentPage()
                latestExtract = extract
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
                                pageTitle: browserController.currentPageTitle(),
                                url: browserController.currentPageURLString(),
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
        let payload: String
        if service == .chatGPT {
            payload = try await browserController.evaluateJavaScript(extractionScript(for: service))
        } else {
            payload = try await backgroundWebView.tm_evaluateJavaScript(extractionScript(for: service))
        }

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

        finishRefresh(with: .failure(error))
    }

    private func finishRefresh(with result: Result<ServiceSnapshot, Error>) {
        extractionScheduled = false
        if service == .chatGPT {
            browserController.endBackgroundPresentationIfNeeded()
        }

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

        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1440, height: 2200), configuration: configuration)
        webView.navigationDelegate = self
        return webView
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

private func extractionScript(for service: ServiceKind) -> String {
    switch service {
    case .claude:
        return """
        (() => {
          const bodyText = document.body ? document.body.innerText : "";
          const interesting = Array.from(document.querySelectorAll('main, main *, section, article, div'))
            .map(node => (node.innerText || '').trim())
            .filter(text => text.length > 0 && text.length < 320)
            .filter(text => /% used|Current session|All models|Sonnet only|Extra usage|Monthly spend limit|Current balance|\\$\\d/i.test(text));
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
          const bodyText = document.body ? (document.body.innerText || document.body.textContent || '') : "";
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
