import ComposableArchitecture
import UIKit

extension FeedbackGeneratorClient {
  public static var live: Self {
    let generator = UISelectionFeedbackGenerator()
    return Self(
      prepare: { await generator.prepare() },
      selectionChanged: { await generator.selectionChanged() }
    )
  }
}
