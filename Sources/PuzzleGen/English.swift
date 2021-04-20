import Gen
import SharedModels

extension Gen {
  public var three: Gen<Three<Value>> {
    zip(self, self, self).map(Three.init)
  }
}

public func randomCubes(for letter: Gen<String>) -> Gen<Puzzle> {
  zip(letter, letter, letter)
    .map { left, right, top in
      Cube(
        left: .init(letter: left, side: .left),
        right: .init(letter: right, side: .right),
        top: .init(letter: top, side: .top)
      )
    }
    .three
    .three
    .three
}

// MARK: - Letter distributions

// https://boardgamegeek.com/geeklist/182883/letter-distributions-word-games/page/1
public let isowordsLetter = Gen.frequency(
  (16, .always("A")),
  (4, .always("B")),
  (6, .always("C")),
  (8, .always("D")),
  (24, .always("E")),
  (4, .always("F")),
  (5, .always("G")),
  (5, .always("H")),
  (13, .always("I")),
  (2, .always("J")),
  (2, .always("K")),
  (7, .always("L")),
  (6, .always("M")),
  (13, .always("N")),
  (15, .always("O")),
  (4, .always("P")),
  (2, .always("QU")),
  (13, .always("R")),
  (10, .always("S")),
  (15, .always("T")),
  (7, .always("U")),
  (3, .always("V")),
  (4, .always("W")),
  (2, .always("X")),
  (4, .always("Y")),
  (2, .always("Z"))
)
