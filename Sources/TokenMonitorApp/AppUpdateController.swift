import Foundation

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

    func checkForUpdates() {
        // Updates are delivered by the Mac App Store for MAS builds.
    }
}

#else

import Sparkle

@MainActor
final class AppUpdateController: NSObject, ObservableObject {
    static let shared = AppUpdateController()

    private let updaterController: SPUStandardUpdaterController

    private override init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        super.init()
    }

    var automaticallyChecksForUpdates: Bool {
        get {
            updaterController.updater.automaticallyChecksForUpdates
        }
        set {
            updaterController.updater.automaticallyChecksForUpdates = newValue
        }
    }

    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
}

#endif
