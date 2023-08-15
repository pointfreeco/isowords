import AppAudioLibrary
import AppClipAudioLibrary
import ComposableArchitecture
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
        store: Store(
          initialState: Onboarding.State(presentationStyle: .firstLaunch)
        ) {
          Onboarding()
            .dependency(
              \.audioPlayer, .live(bundles: [AppClipAudioLibrary.bundle, AppAudioLibrary.bundle])
            )
            .dependency(\.userDefaults, .noop)
        }
      )
    }
  }
}
