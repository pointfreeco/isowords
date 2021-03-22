import PuzzleGen
import SharedModels

struct ReplayableCharacter {
  var letter: String
  var index: LatticePoint
  var side: CubeFace.Side
}

let replayableWords: [[ReplayableCharacter]] = [
  [
    .init(letter: "S",  index: LatticePoint(x: 1, y: 1, z: 2)!, side: .left),
    .init(letter: "E",  index: LatticePoint(x: 2, y: 2, z: 2)!, side: .left),
    .init(letter: "QU", index: LatticePoint(x: 1, y: 2, z: 2)!, side: .left),
    .init(letter: "E",  index: LatticePoint(x: 0, y: 2, z: 2)!, side: .left),
    .init(letter: "S",  index: LatticePoint(x: 0, y: 2, z: 2)!, side: .top),
    .init(letter: "T",  index: LatticePoint(x: 1, y: 2, z: 2)!, side: .top),
    .init(letter: "E",  index: LatticePoint(x: 0, y: 2, z: 1)!, side: .right),
    .init(letter: "R",  index: LatticePoint(x: 0, y: 2, z: 1)!, side: .top),
    .init(letter: "I",  index: LatticePoint(x: 1, y: 2, z: 0)!, side: .top),
    .init(letter: "N",  index: LatticePoint(x: 2, y: 2, z: 0)!, side: .top),
    .init(letter: "G",  index: LatticePoint(x: 2, y: 2, z: 0)!, side: .right),
  ],
]

extension Puzzle {
  static var trailer: Self {
    var puzzle = randomCubes(for: isowordsLetter).run()

    puzzle[.one][.two][.one].left.useCount = 3

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
