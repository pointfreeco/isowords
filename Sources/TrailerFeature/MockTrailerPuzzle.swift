import PuzzleGen
import SharedModels

struct ReplayableCharacter {
  var letter: String
  var index: LatticePoint
  var side: CubeFace.Side
}

let replayableWords: [[ReplayableCharacter]] = [
  [
    .init(letter: "Y", index: LatticePoint(x: 2, y: 0, z: 2)!, side: .left),
    .init(letter: "U", index: LatticePoint(x: 2, y: 0, z: 2)!, side: .top),
    .init(letter: "L", index: LatticePoint(x: 1, y: 0, z: 1)!, side: .left),
    .init(letter: "E", index: LatticePoint(x: 0, y: 1, z: 1)!, side: .left),
    .init(letter: "T", index: LatticePoint(x: 1, y: 0, z: 1)!, side: .top),
    .init(letter: "I", index: LatticePoint(x: 1, y: 0, z: 0)!, side: .right),
    .init(letter: "D", index: LatticePoint(x: 1, y: 0, z: 0)!, side: .top),
    .init(letter: "E", index: LatticePoint(x: 0, y: 1, z: 1)!, side: .right),
    .init(letter: "S", index: LatticePoint(x: 0, y: 1, z: 1)!, side: .top),
  ],
]

extension Puzzle {
  static var trailer: Self {
    var puzzle = randomCubes(for: isowordsLetter).run()

    puzzle[.zero][.two][.zero].top.useCount = 3
    puzzle[.one][.two][.zero].top.useCount = 3
    puzzle[.two][.two][.zero].top.useCount = 3
    puzzle[.zero][.two][.one].top.useCount = 3
    puzzle[.one][.two][.one].top.useCount = 3
    puzzle[.two][.two][.one].top.useCount = 3
    puzzle[.zero][.two][.two].top.useCount = 3
    puzzle[.one][.two][.two].top.useCount = 3
    puzzle[.two][.two][.two].top.useCount = 3

    puzzle[.one][.one][.zero].top.useCount = 3
    puzzle[.one][.one][.one].top.useCount = 3
    puzzle[.one][.one][.two].top.useCount = 3
    puzzle[.two][.one][.zero].top.useCount = 3
    puzzle[.two][.one][.one].top.useCount = 3
    puzzle[.two][.one][.two].top.useCount = 3

    puzzle[.two][.zero][.zero].top.useCount = 3
    puzzle[.two][.zero][.one].top.useCount = 3

    puzzle[.zero][.zero][.two].left.useCount = 3
    puzzle[.zero][.one][.two].left.useCount = 3
    puzzle[.one][.zero][.two].left.useCount = 3

    var setFaces: Set<IndexedCubeFace> = []

    for (_, word) in replayableWords.enumerated() {
      for (_, character) in word.enumerated() {
        let face = IndexedCubeFace(index: character.index, side: character.side)
        defer { setFaces.insert(face) }
        if setFaces.contains(face) && puzzle[face].letter != character.letter {
//          fatalError("A previously set face was overriden with a different letter.")
        }
        puzzle[face].letter = character.letter
      }
    }

    return puzzle
  }
}
