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
          initialState: .init(presentationStyle: .firstLaunch),
          reducer: onboardingReducer,
          environment: OnboardingEnvironment(
            audioPlayer: .noop,
            backgroundQueue: DispatchQueue.global().eraseToAnyScheduler(),
            dictionary: .sqlite(),
            feedbackGenerator: .live,
            lowPowerMode: .live,
            mainQueue: .main,
            mainRunLoop: .main,
            userDefaults: .noop
          )
        )
      )
    }
  }
}
