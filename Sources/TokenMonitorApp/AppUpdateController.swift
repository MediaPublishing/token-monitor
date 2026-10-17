import AppKit
import Foundation
import Combine

#if MAS_BUILD

@MainActor
final class AppUpdateController: NSObject, ObservableObject {
    static let shared = AppUpdateController()

    private override init() {
        super.init()
    }

    var automaticallyChecksForUpdates: Bool {
        get { false }
        set { _ = newValue }
    }
    var automaticallyDownloadsUpdates: Bool {
        get { false }
        set { _ = newValue }
    }
    var automaticDownloadsEnabled: Bool { false }
    var isPreparingUpdate: Bool { false }

    func checkForUpdates() {
        // Updates are delivered by the Mac App Store for MAS builds.
    }

    @Published private(set) var availableVersion: String?
    var statusText: String { "Updates are delivered by the Mac App Store." }
    var nextCheckDate: Date? { nil }
    var diagnosticsText: String { "Update channel: Mac App Store" }
    func start() {}
}

#else

import Sparkle

@MainActor
final class AppUpdateController: NSObject, ObservableObject, SPUUpdaterDelegate, @preconcurrency SPUStandardUserDriverDelegate {
    static let shared = AppUpdateController()

    @Published private(set) var availableVersion: String?
    @Published private(set) var statusText = "Not checked this session"
    @Published private(set) var nextCheckDate: Date?
    @Published private(set) var automaticDownloadsEnabled = false
    @Published private(set) var isPreparingUpdate = false

    private static let lastResultKey = "lastAppUpdateResult"
    private var updaterController: SPUStandardUpdaterController!
    private var started = false
    private var subscriptions = Set<AnyCancellable>()

    private override init() {
        super.init()
        updaterController = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: self,
            userDriverDelegate: self
        )
        automaticDownloadsEnabled = updaterController.updater.automaticallyDownloadsUpdates
        updaterController.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: RunLoop.main)
            .sink { [weak self] ready in
                if ready { self?.presentRequestedUpdateIfReady() }
            }
            .store(in: &subscriptions)
        updaterController.updater.publisher(for: \.automaticallyDownloadsUpdates)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.automaticDownloadsEnabled = self.updaterController.updater.automaticallyDownloadsUpdates
            }
            .store(in: &subscriptions)
    }

    func start() {
        guard !started else { return }
        do {
            try updaterController.updater.start()
            started = true
        } catch {
            recordError(error as NSError)
        }
    }

    var automaticallyChecksForUpdates: Bool {
        get {
            updaterController.updater.automaticallyChecksForUpdates
        }
        set {
            let wasEnabled = automaticallyChecksForUpdates
            updaterController.updater.automaticallyChecksForUpdates = newValue
            // Enabling checks should not wait for the previously scheduled daily check.
            if newValue && !wasEnabled && started && !updaterController.updater.sessionInProgress {
                updaterController.updater.checkForUpdatesInBackground()
            }
        }
    }

    func checkForUpdates() {
        start()
        guard started, !isPreparingUpdate else { return }
        isPreparingUpdate = true
        if !updaterController.updater.canCheckForUpdates {
            statusText = "Preparing update. Waiting for the background download..."
        }
        // A background download cannot be focused yet. KVO resumes this same request when ready.
        DispatchQueue.main.async { [weak self] in self?.presentRequestedUpdateIfReady() }
    }

    private func presentRequestedUpdateIfReady() {
        guard isPreparingUpdate, updaterController.updater.canCheckForUpdates else { return }
        AppDelegate.shared?.closePopover()
        NSApp.activate(ignoringOtherApps: true)
        isPreparingUpdate = false
        updaterController.checkForUpdates(nil)
    }

    var automaticallyDownloadsUpdates: Bool {
        get { updaterController.updater.automaticallyDownloadsUpdates }
        set {
            updaterController.updater.automaticallyDownloadsUpdates = newValue
            automaticDownloadsEnabled = newValue
        }
    }

    var diagnosticsText: String {
        let updater = updaterController.updater
        func dateText(_ date: Date?) -> String {
            date.map { ISO8601DateFormatter().string(from: $0) } ?? "none"
        }
        return [
            "Update channel: Sparkle",
            "App location: \(Bundle.main.bundleURL.path)",
            "Feed: \(updater.feedURL?.absoluteString ?? "not configured")",
            "Updater started: \(started)",
            "Automatic checks: \(updater.automaticallyChecksForUpdates)",
            "Automatic downloads: \(updater.automaticallyDownloadsUpdates)",
            "Check interval: \(Int(updater.updateCheckInterval)) seconds",
            "Last check: \(dateText(updater.lastUpdateCheckDate))",
            "Next scheduled check: \(dateText(nextCheckDate))",
            "Session in progress: \(updater.sessionInProgress)",
            "Can show update: \(updater.canCheckForUpdates)",
            "Review requested: \(isPreparingUpdate)",
            "Available version: \(availableVersion ?? "none")",
            "Current result: \(statusText)",
            "Last recorded result: \(UserDefaults.standard.string(forKey: Self.lastResultKey) ?? "none")"
        ].joined(separator: "\n")
    }

    func updater(_ updater: SPUUpdater, mayPerform updateCheck: SPUUpdateCheck) throws {
        statusText = "Checking for updates..."
        nextCheckDate = nil
    }

    func updater(_ updater: SPUUpdater, willScheduleUpdateCheckAfterDelay delay: TimeInterval) {
        nextCheckDate = Date().addingTimeInterval(delay)
    }

    func updaterWillNotScheduleUpdateCheck(_ updater: SPUUpdater) {
        nextCheckDate = nil
    }

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        availableVersion = item.displayVersionString
        recordResult("Update \(item.displayVersionString) available")
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) {
        availableVersion = nil
        recordResult(error.localizedDescription)
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        let error = error as NSError
        if error.domain == SUSparkleErrorDomain && error.code == SUError.noUpdateError.rawValue { return }
        recordError(error)
    }

    func updater(_ updater: SPUUpdater, userDidMake choice: SPUUserUpdateChoice,
                 forUpdate item: SUAppcastItem, state: SPUUserUpdateState) {
        switch choice {
        case .skip:
            availableVersion = nil
            recordResult("Skipped update \(item.displayVersionString)")
        case .dismiss:
            recordResult("Update \(item.displayVersionString) postponed")
        case .install:
            recordResult("Installing update \(item.displayVersionString)")
        @unknown default: break
        }
    }

    var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverShouldHandleShowingScheduledUpdate(_ update: SUAppcastItem,
                                                              andInImmediateFocus immediateFocus: Bool) -> Bool {
        // Keep scheduled reminders in our menu instead of opening an unseen background window.
        false
    }

    func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool,
                                                   forUpdate update: SUAppcastItem, state: SPUUserUpdateState) {
        availableVersion = update.displayVersionString
    }

    private func recordResult(_ result: String) {
        statusText = result
        UserDefaults.standard.set("\(ISO8601DateFormatter().string(from: Date())): \(result)", forKey: Self.lastResultKey)
    }

    private func recordError(_ error: NSError) {
        isPreparingUpdate = false
        // Codes identify transport, signing and installation failures without recording URLs or credentials.
        var codes: [String] = []
        var current: NSError? = error
        while let failure = current, codes.count < 4 {
            let code = "\(failure.domain) \(failure.code)"
            if codes.last == code { break }
            codes.append(code)
            current = failure.userInfo[NSUnderlyingErrorKey] as? NSError
        }
        recordResult("Update failed (\(codes.joined(separator: "; "))). Try Check for Updates.")
        statusText = "Update failed. Try Check for Updates."
    }
}

#endif
