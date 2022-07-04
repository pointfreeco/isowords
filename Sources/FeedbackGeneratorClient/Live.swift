import ComposableArchitecture
import UIKit

extension FeedbackGeneratorClient {
  public static var live: Self {
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
  }
}
