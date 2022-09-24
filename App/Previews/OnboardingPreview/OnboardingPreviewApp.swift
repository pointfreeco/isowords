import AppAudioLibrary
import AppClipAudioLibrary
import DictionarySqliteClient
import OnboardingFeature
import Styleguide
import SwiftUI

@main
struct OnboardingPreviewApp: App {
  init() {
    Styleguide.registerFonts()
  }

  var body: some Scene {
    WindowGroup {
      OnboardingView(
        store: .init(
          initialState: Onboarding.State(presentationStyle: .firstLaunch),
          reducer: Onboarding()
            .dependency(
              \.audioPlayer, .live(bundles: [AppClipAudioLibrary.bundle, AppAudioLibrary.bundle])
            )
            .dependency(\.userDefaults, .noop)
        )
      )
    }
  }
}
