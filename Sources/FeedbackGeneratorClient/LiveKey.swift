import Dependencies
import UIKit

extension FeedbackGeneratorClient: DependencyKey {
  public static let liveValue = {
    let generator = UISelectionFeedbackGenerator()
    return Self(
      prepare: { await generator.prepare() },
      selectionChanged: { await generator.selectionChanged() }
    )
  }()
}
