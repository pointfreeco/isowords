import PuzzleGen
import SharedModels

struct ReplayableCharacter {
  var letter: String
  var index: LatticePoint
  var side: CubeFace.Side
}

let replayableWords: [[ReplayableCharacter]] = [
  [
    .init(letter: "S", index: LatticePoint(x: 0, y: 2, z: 1)!, side: .top),
    .init(letter: "A", index: LatticePoint(x: 0, y: 2, z: 0)!, side: .top),
    .init(letter: "Y", index: LatticePoint(x: 1, y: 2, z: 0)!, side: .top),
  ],
  [
    .init(letter: "H", index: LatticePoint(x: 0, y: 2, z: 2)!, side: .top),
    .init(letter: "E", index: LatticePoint(x: 1, y: 2, z: 2)!, side: .top),
    .init(letter: "L", index: LatticePoint(x: 1, y: 2, z: 1)!, side: .top),
    .init(letter: "L", index: LatticePoint(x: 2, y: 2, z: 0)!, side: .top),
    .init(letter: "O", index: LatticePoint(x: 2, y: 2, z: 1)!, side: .top),
  ],
  [
    .init(letter: "T", index: LatticePoint(x: 2, y: 2, z: 2)!, side: .top),
    .init(letter: "O", index: LatticePoint(x: 2, y: 2, z: 1)!, side: .top),
  ],
  [
    .init(letter: "I", index: LatticePoint(x: 0, y: 2, z: 2)!, side: .left),
    .init(letter: "S", index: LatticePoint(x: 0, y: 1, z: 2)!, side: .left),
    .init(letter: "O", index: LatticePoint(x: 1, y: 1, z: 2)!, side: .left),
    .init(letter: "W", index: LatticePoint(x: 2, y: 2, z: 2)!, side: .left),
    .init(letter: "O", index: LatticePoint(x: 2, y: 1, z: 2)!, side: .right),
    .init(letter: "R", index: LatticePoint(x: 2, y: 2, z: 2)!, side: .right),
    .init(letter: "D", index: LatticePoint(x: 2, y: 2, z: 1)!, side: .right),
    .init(letter: "S", index: LatticePoint(x: 2, y: 2, z: 0)!, side: .right),
  ],
  [
    .init(letter: "A", index: LatticePoint(x: 0, y: 2, z: 0)!, side: .top)
  ],
  [
    .init(letter: "N", index: LatticePoint(x: 1, y: 2, z: 2)!, side: .left),
    .init(letter: "E", index: LatticePoint(x: 1, y: 2, z: 2)!, side: .top),
    .init(letter: "W", index: LatticePoint(x: 2, y: 2, z: 2)!, side: .left),
  ],
  [
    .init(letter: "W", index: LatticePoint(x: 2, y: 2, z: 2)!, side: .left),
    .init(letter: "O", index: LatticePoint(x: 2, y: 1, z: 2)!, side: .right),
    .init(letter: "R", index: LatticePoint(x: 2, y: 2, z: 2)!, side: .right),
    .init(letter: "D", index: LatticePoint(x: 2, y: 2, z: 1)!, side: .right),
  ],
  [
    .init(letter: "S", index: LatticePoint(x: 2, y: 2, z: 1)!, side: .left),
    .init(letter: "E", index: LatticePoint(x: 2, y: 1, z: 2)!, side: .top),
    .init(letter: "A", index: LatticePoint(x: 2, y: 1, z: 2)!, side: .left),
    .init(letter: "R", index: LatticePoint(x: 2, y: 0, z: 2)!, side: .right),
    .init(letter: "C", index: LatticePoint(x: 2, y: 1, z: 1)!, side: .right),
    .init(letter: "H", index: LatticePoint(x: 2, y: 0, z: 0)!, side: .right),
  ],
  [
    .init(letter: "G", index: LatticePoint(x: 2, y: 0, z: 2)!, side: .left),
    .init(letter: "A", index: LatticePoint(x: 2, y: 1, z: 2)!, side: .left),
    .init(letter: "M", index: LatticePoint(x: 1, y: 2, z: 2)!, side: .right),
    .init(letter: "E", index: LatticePoint(x: 1, y: 2, z: 2)!, side: .top),
  ],
  [
    .init(letter: "F", index: LatticePoint(x: 2, y: 0, z: 1)!, side: .right),
    .init(letter: "O", index: LatticePoint(x: 2, y: 1, z: 2)!, side: .right),
    .init(letter: "R", index: LatticePoint(x: 2, y: 0, z: 2)!, side: .right),
  ],
  [
    .init(letter: "Y", index: LatticePoint(x: 2, y: 0, z: 2)!, side: .top),
    .init(letter: "O", index: LatticePoint(x: 1, y: 1, z: 2)!, side: .left),
    .init(letter: "U", index: LatticePoint(x: 1, y: 1, z: 2)!, side: .right),
    .init(letter: "R", index: LatticePoint(x: 1, y: 0, z: 2)!, side: .left),
  ],
  [
    .init(letter: "P", index: LatticePoint(x: 1, y: 2, z: 1)!, side: .left),
    .init(letter: "H", index: LatticePoint(x: 0, y: 2, z: 2)!, side: .top),
    .init(letter: "O", index: LatticePoint(x: 0, y: 2, z: 2)!, side: .right),
    .init(letter: "N", index: LatticePoint(x: 1, y: 1, z: 2)!, side: .top),
    .init(letter: "E", index: LatticePoint(x: 2, y: 1, z: 1)!, side: .left),
  ],
]

extension Puzzle {
  static var trailer: Self {
    var puzzle = randomCubes(for: isowordsLetter).run()

    var setFaces: Set<IndexedCubeFace> = []

    for (_, word) in replayableWords.enumerated() {
      for (_, character) in word.enumerated() {
        let face = IndexedCubeFace(index: character.index, side: character.side)
        defer { setFaces.insert(face) }
        if setFaces.contains(face) && puzzle[face].letter != character.letter {
          fatalError("A previously set face was overriden with a different letter.")
        }
        puzzle[face].letter = character.letter
      }
    }

    return puzzle
  }
}
