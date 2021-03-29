import ApiClient
import AppClipAudioLibrary
import Build
import ComposableArchitecture
import DemoFeature
import DictionaryFileClient
import Styleguide
import SwiftUI

@main
struct AppClipApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    WindowGroup {
      DemoView(
        store: appDelegate.store
      )
    }
  }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
  let store = Store(
    initialState: DemoState(),
    reducer: demoReducer,
    environment: .live
  )
  lazy var viewStore = ViewStore(
    self.store.scope(
      state: { _ in () },
      action: { (_: Void) in DemoAction.didFinishLaunching }
    ),
    removeDuplicates: ==
  )

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    Styleguide.registerFonts()
    self.viewStore.send(())
    return true
  }
}

extension DemoEnvironment {
  static var live: Self {
    var apiClient = ApiClient.noop
    apiClient.request = { route in
      switch route {
      case .api,
        .appSiteAssociation,
        .appStore,
        .authenticate,
        .download,
        .sharedGame,
        .home,
        .pressKit,
        .privacyPolicy:
        return .none

      case let .demo(.submitGame(gameRequest)):
        #if DEBUG
          let baseUrl = URL(string: "https://isowords-staging.herokuapp.com")!
        #else
          let baseUrl = URL(string: "https://www.isowords.xyz")!
        #endif

        var request = URLRequest(
          url:
            baseUrl
            .appendingPathComponent("demo")
            .appendingPathComponent("games")
        )
        request.httpMethod = "POST"
        request.httpBody = try? JSONEncoder().encode(gameRequest)

        return URLSession.shared.dataTaskPublisher(for: request)
          .eraseToEffect()
      }
    }

    return Self(
      apiClient: apiClient,
      applicationClient: .live,
      audioPlayer: .live(
        bundles: [
          AppClipAudioLibrary.bundle
        ]
      ),
      backgroundQueue: DispatchQueue(label: "background-queue").eraseToAnyScheduler(),
      build: .live,
      dictionary: .file(),
      feedbackGenerator: .live,
      lowPowerMode: .live,
      mainQueue: .main,
      mainRunLoop: .main,
      serverConfig: .noop,
      userDefaults: .live()
    )
  }
}
