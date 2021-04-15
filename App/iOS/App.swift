import ApiClientLive
import AppAudioLibrary
import AppClipAudioLibrary
import AppFeature
import Build
import ComposableArchitecture
import CryptoKit
import DictionarySqliteClient
import Overture
import ServerConfig
import ServerConfigClient
import Styleguide
import SwiftUI
import UIApplicationClient

final class AppDelegate: NSObject, UIApplicationDelegate {
  let store = Store(
    initialState: .init(),
    reducer: appReducer,
    environment: .live
  )
  private(set) lazy var viewStore = ViewStore(self.store.stateless)

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    self.viewStore.send(.appDelegate(.didFinishLaunching))
    return true
  }

  func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    self.viewStore.send(.appDelegate(.didRegisterForRemoteNotifications(.success(deviceToken))))
  }

  func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    self.viewStore.send(
      .appDelegate(.didRegisterForRemoteNotifications(.failure(error as NSError)))
    )
  }

  func application(
    _ application: UIApplication,
    configurationForConnecting connectingSceneSession: UISceneSession,
    options: UIScene.ConnectionOptions
  ) -> UISceneConfiguration {
    updateObject(
      .init(
        name: "isowords Configuration",
        sessionRole: connectingSceneSession.role
      )
    ) {
      $0.delegateClass = SceneDelegate.self
    }
  }

  final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    func windowScene(
      _ windowScene: UIWindowScene,
      performActionFor shortcutItem: UIApplicationShortcutItem,
      completionHandler: @escaping (Bool) -> Void
    ) {
      self.appDelegate.viewStore.send(
        .appDelegate(.scene(.quickAction(type: shortcutItem.type)))
      )
    }
  }
}

@main
struct IsowordsApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  @Environment(\.scenePhase) private var scenePhase

  init() {
    Styleguide.registerFonts()
  }

  var body: some Scene {
    WindowGroup {
      AppView(store: self.appDelegate.store)
    }
    .onChange(of: self.scenePhase) {
      self.appDelegate.viewStore.send(.didChangeScenePhase($0))
    }
  }
}

extension AppEnvironment {
  static var live: Self {
    let apiClient = ApiClient.live
    let build = Build.live

    return Self(
      apiClient: apiClient,
      applicationClient: .live,
      audioPlayer: .noop,
//      audioPlayer: .live(
//        bundles: [
//          AppAudioLibrary.bundle,
//          AppClipAudioLibrary.bundle,
//        ]
//      ),
      backgroundQueue: DispatchQueue(label: "background-queue").eraseToAnyScheduler(),
      build: build,
      database: .live(
        path: FileManager.default
          .urls(for: .documentDirectory, in: .userDomainMask)
          .first!
          .appendingPathComponent("co.pointfree.Isowords")
          .appendingPathComponent("Isowords.sqlite3")
      ),
      deviceId: .live,
      dictionary: .sqlite(),
      feedbackGenerator: .live,
      fileClient: .live,
      gameCenter: .live,
      lowPowerMode: .live,
      mainQueue: .main,
      mainRunLoop: .main,
      remoteNotifications: .live,
      serverConfig: .live(apiClient: apiClient, build: build),
      setUserInterfaceStyle: { userInterfaceStyle in
        .fireAndForget {
          UIApplication.shared.windows.first?.overrideUserInterfaceStyle = userInterfaceStyle
        }
      },
      storeKit: .live(),
      timeZone: { .autoupdatingCurrent },
      userDefaults: .live(),
      userNotifications: .live
    )
  }
}

extension ApiClient {
  static let live = Self.live(
    sha256: { Data(SHA256.hash(data: $0)) }
  )
}

extension ServerConfigClient {
  static func live(apiClient: ApiClient, build: Build) -> Self {
    .live(
      fetch: {
        apiClient.apiRequest(route: .config(build: build.number()), as: ServerConfig.self)
          .mapError { $0 as Error }
          .eraseToEffect()
      }
    )
  }
}
