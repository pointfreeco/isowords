import ApiClientLive
import AppAudioLibrary
import AppClipAudioLibrary
import AppFeature
import Build
import ComposableArchitecture
import DictionarySqliteClient
import ServerConfig
import ServerConfigClient
import Styleguide
import SwiftUI
import UIApplicationClient

final class AppDelegate: NSObject, UIApplicationDelegate {
  let store = Store(
    initialState: AppReducer.State(),
    reducer: AppReducer().transformDependency(\.self) {
      $0.audioPlayer = .live(bundles: [AppAudioLibrary.bundle, AppClipAudioLibrary.bundle])
      $0.database = .live(
        path: FileManager.default
          .urls(for: .documentDirectory, in: .userDomainMask)
          .first!
          .appendingPathComponent("co.pointfree.Isowords")
          .appendingPathComponent("Isowords.sqlite3")
      )
      $0.serverConfig = .live(apiClient: $0.apiClient, build: $0.build)
    }
  )

  var viewStore: ViewStore<Void, AppReducer.Action> {
    ViewStore(self.store.stateless)
  }

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
    self.viewStore.send(.appDelegate(.didRegisterForRemoteNotifications(.failure(error))))
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

extension ServerConfigClient {
  static func live(apiClient: ApiClient, build: Build) -> Self {
    .live(
      fetch: {
        try await apiClient
          .apiRequest(route: .config(build: build.number()), as: ServerConfig.self)
      }
    )
  }
}
