import ComposableArchitecture

#if canImport(UIKit)
  import UIKit
#endif
#if canImport(AppKit)
  import AppKit
#endif

extension FeedbackGeneratorClient {
  public static var live: Self {
    #if canImport(UIKit)
      let generator = UISelectionFeedbackGenerator()
      return Self(
        prepare: {
          generator.prepare()
        },
        selectionChanged: {
          generator.selectionChanged() 
        }
      )
    #else
      let generator = NSHapticFeedbackManager.defaultPerformer
      return Self(
        prepare: {
        },
        selectionChanged: {
          generator.perform(.levelChange, performanceTime: .default)
        }
      )
    #endif
  }
}
