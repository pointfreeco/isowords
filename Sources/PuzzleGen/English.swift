import Gen
import NonEmpty
import SharedModels

extension Gen {
  public var three: Gen<Three<Value>> {
    zip(self, self, self).map(Three.init)
  }
}

public func randomCubes(for letter: Gen<NonEmptyString>) -> Gen<Puzzle> {
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
  (16, .always(NonEmptyString("A"))),
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

// MARK: - Scoring

public func score(
  _ word: NonEmptyString,
  with scoring: [Character: Int] = scoring
) -> Int {
  (word.uppercased() as NonEmptyString)
    .reduce(into: 0) { $0 += scoring[$1] ?? 0 }
    * word.count
    * max(1, word.count - 3)
}

public let scoring: [Character: Int] = [
  "A": 1,
  "B": 4,
  "C": 4,
  "D": 3,
  "E": 1,
  "F": 5,
  "G": 3,
  "H": 5,
  "I": 1,
  "J": 9,
  "K": 6,
  "L": 2,
  "M": 4,
  "N": 2,
  "O": 1,
  "P": 4,
  "Q": 12,
  "R": 2,
  "S": 1,
  "T": 2,
  "U": 1,
  "V": 5,
  "W": 5,
  "X": 9,
  "Y": 5,
  "Z": 11,
]
