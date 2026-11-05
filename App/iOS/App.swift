import ApiClientLive
import AppAudioLibrary
import AppClipAudioLibrary
import AppFeature
import AudioPlayerClient
import Build
import ComposableArchitecture
import Dependencies
import DictionarySqliteClient
import ServerConfig
import ServerConfigClient
import Styleguide
import SwiftUI
import UIApplicationClient

final class AppDelegate: NSObject, UIApplicationDelegate {
  let rootStore = Store(initialState: AppReducer.State()) {
    AppReducer().transformDependency(\.self) {
      $0.audioPlayer = .liveValue
      $0.database = .live(
        path: FileManager.default
          .urls(for: .documentDirectory, in: .userDomainMask)
          .first!
          .appendingPathComponent("co.pointfree.Isowords")
          .appendingPathComponent("Isowords.sqlite3")
      )
      $0.serverConfig = .live(apiClient: $0.apiClient, build: $0.build)
    }
  }

  var store: StoreOf<AppDelegateReducer> { rootStore.scope(\.appDelegate) }

  func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    store.send(.didRegisterForRemoteNotifications(.success(deviceToken)))
  }

  func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    store.send(.didRegisterForRemoteNotifications(.failure(error)))
  }
}

@main
struct IsowordsApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  @Environment(\.scenePhase) private var scenePhase

  var store: StoreOf<AppReducer> { appDelegate.rootStore }

  init() {
    Styleguide.registerFonts()
  }

  var body: some Scene {
    WindowGroup {
      AppView(store: store)
    }
    .onChange(of: scenePhase) { _, newPhase in
      store.send(.didChangeScenePhase(newPhase))
    }
  }
}

extension AudioPlayerClient {
  static let liveValue = Self.live(bundles: [AppAudioLibrary.bundle, AppClipAudioLibrary.bundle])
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
