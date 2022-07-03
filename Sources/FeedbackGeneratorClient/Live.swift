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
          .fireAndForget { generator.prepare() }
        },
        prepareAsync: { await generator.prepare() },
        selectionChanged: {
          .fireAndForget { generator.selectionChanged() }
        },
        selectionChangedAsync: { await generator.selectionChanged() }
      )
    #else
      let generator = NSHapticFeedbackManager.defaultPerformer
      return Self(
        prepare: {
          .fireAndForget {}
        },
        selectionChanged: {
          .fireAndForget {
            generator.perform(.levelChange, performanceTime: .default)
          }
        }
      )
    #endif
  }
}
