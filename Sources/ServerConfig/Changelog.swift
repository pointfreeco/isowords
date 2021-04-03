public struct Changelog: Codable, Hashable {
  public var changes: [Change]

  public init(
    changes: [Change]
  ) {
    self.changes = changes
  }

  public struct Change: Codable, Hashable {
    public var build: Int
    public var log: String
    public var version: String

    public init(
      version: String,
      build: Int,
      log: String
    ) {
      self.build = build
      self.log = log
      self.version = version
    }
  }
}

extension Changelog {
  public static let current = Self(
    changes: [
      .init(
        version: "1.2",
        build: 102,
        log: """
  • If you have ever frantically tapped the final word in a timed game only to hit "new game" on the game over screen before seeing your results, we've got some good news :) These buttons are no longer immediately tappable!
  • If you've ever wondered how in the world some people find the words they do, you can now tap any word in the Vocab leaderboard to see it spelled out before your very eyes.
  • We've made a few small performance optimizations.
  • We fixed a bug that could occasionally clear out a solo saved game.
  """
      ),

      .init(
        version: "1.1",
        build: 98,
        log: """
  • A new leaderboard for "interesting" vocab. The highest-scoring words aren't always the most interesting! Check it out to see how your words rank.
  • A new accessibility setting to "reduce animation"
  • Better support for larger text sizes
  • Other bug fixes
  """
      )
    ]
  )
}
