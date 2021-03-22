import AppAudioLibrary
import AppClipAudioLibrary
import ComposableArchitecture
import Overture
import Styleguide
import SwiftUI
import TrailerFeature

final class AppDelegate: NSObject, UIApplicationDelegate {
  let store = Store(
    initialState: .init(),
    reducer: trailerReducer,
    environment: TrailerEnvironment(
      audioPlayer: .live(
        bundles: [
          AppAudioLibrary.bundle,
          AppClipAudioLibrary.bundle,
        ]
      ),
      backgroundQueue: DispatchQueue.main.eraseToAnyScheduler(),
      dictionary: .init(
        contains: { string, _ in
          [
            "SEQUESTERING",
          ]
          .contains(string.uppercased())
        },
        load: { _ in true },
        lookup: { _, _ in nil },
        randomCubes: { _ in .mock },
        unload: { _ in }
      ),
      mainQueue: DispatchQueue.main.eraseToAnyScheduler(),
      mainRunLoop: RunLoop.main.eraseToAnyScheduler()
    )
  )

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    Styleguide.registerFonts()
    return true
  }
}

@main
struct TrailerPreviewApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    WindowGroup {
      TrailerView(store: self.appDelegate.store)
        .statusBar(hidden: true)
    }
  }
}
