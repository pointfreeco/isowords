import Foundation

public struct ResultEnvelope: Equatable {
  public var outOf: Int
  public var results: [Result]

  public init(
    outOf: Int = 0,
    results: [Result] = []
  ) {
    self.outOf = outOf
    self.results = results
  }

  public struct Result: Equatable, Identifiable {
    public var denseRank: Int
    public var id: UUID
    public var isYourScore: Bool
    public var rank: Int
    public var score: Int
    public var subtitle: String?
    public var title: String

    public init(
      denseRank: Int,
      id: UUID,
      isYourScore: Bool = false,
      rank: Int,
      score: Int,
      subtitle: String? = nil,
      title: String
    ) {
      self.denseRank = denseRank
      self.id = id
      self.isYourScore = isYourScore
      self.rank = rank
      self.score = score
      self.subtitle = subtitle
      self.title = title
    }
  }

  public var contiguousResults: ArraySlice<Result> {
    for (index, prevIndex) in zip(self.results.indices.dropFirst(), self.results.indices) {
      if self.results[index].denseRank - self.results[prevIndex].denseRank > 1 {
        return self.results[self.results.startIndex..<index]
      }
    }
    return self.results[...]
  }

  public var nonContiguousResult: Result? {
    guard self.results.count >= 2
    else { return nil }

    let lastIndex = self.results.count - 1
    if self.results[lastIndex].denseRank - self.results[lastIndex - 1].denseRank > 1 {
      return self.results.last
    } else {
      return nil
    }
  }
}
