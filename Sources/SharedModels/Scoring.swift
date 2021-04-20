public func score(
  _ word: String,
  with scoring: [Character: Int] = scoring
) -> Int {
  word.uppercased().reduce(into: 0) { $0 += scoring[$1] ?? 0 }
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
