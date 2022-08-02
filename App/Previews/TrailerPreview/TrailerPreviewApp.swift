import AppAudioLibrary
import AppClipAudioLibrary
import ComposableArchitecture
import Overture
import Styleguide
import SwiftUI
import TrailerFeature

@main
struct TrailerPreviewApp: App {
  init() {
    Styleguide.registerFonts()
  }

  var body: some Scene {
    WindowGroup {
      TrailerView(
        store: .init(
          initialState: Trailer.State(),
          reducer: Trailer()
            .dependency(
              \.audioPlayer, .live(bundles: [
                AppAudioLibrary.bundle,
                AppClipAudioLibrary.bundle,
              ])
            )
            .dependency(
              \.dictionary, .init(
                contains: { string, _ in
                  [
                    "SAY", "HELLO", "TO", "ISOWORDS",
                    "A", "NEW", "WORD", "SEARCH", "GAME",
                    "FOR", "YOUR", "PHONE",
                    "COMING", "NEXT", "YEAR",
                  ]
                    .contains(string.uppercased())
                },
                load: { _ in true },
                lookup: { _, _ in nil },
                randomCubes: { _ in .mock },
                unload: { _ in }
              )
            )
        )
      )
      .statusBar(hidden: true)
    }
  }
}
