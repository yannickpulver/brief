import Combine
import Sparkle

/// Sparkle's updater, observable so the Settings toggle stays in sync.
///
/// The feed (`SUFeedURL`) and public key (`SUPublicEDKey`) live in the Info.plist.
/// The release workflow attaches a signed one-item `appcast.xml` to every release.
@MainActor
final class Updater: ObservableObject {
    static let shared = Updater()

    @Published var automaticallyChecksForUpdates: Bool {
        didSet { controller.updater.automaticallyChecksForUpdates = automaticallyChecksForUpdates }
    }

    let controller = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    private init() {
        automaticallyChecksForUpdates = controller.updater.automaticallyChecksForUpdates
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
