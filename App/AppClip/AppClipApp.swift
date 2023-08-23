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
  init() {
    Styleguide.registerFonts()
  }

  var body: some Scene {
    WindowGroup {
      DemoView(
        store: Store(initialState: Demo.State()) {
          Demo()
        } withDependencies: {
          $0.apiClient = .appClip
          $0.audioPlayer = .live(bundles: [AppClipAudioLibrary.bundle])
          $0.dictionary = .file()
        }
      )
    }
  }
}

extension ApiClient {
  // An instance of the API client that only supports one endpoint: submitting un-authenticated
  // games to the leaderboards.
  static var appClip: Self {
    var apiClient = ApiClient.noop
    apiClient.request = { @Sendable route in
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
        throw CancellationError()

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

        return try await URLSession.shared.data(for: request)
      }
    }

    return apiClient
  }
}
