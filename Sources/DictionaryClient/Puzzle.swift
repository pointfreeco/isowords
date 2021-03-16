import SharedModels

extension Puzzle {
  public func hasPlayableWords(in dictionary: DictionaryClient) -> Bool {
    guard let lookup = dictionary.lookup else { return true }

    let playableFaces = IndexedCubeFace.cubeIndices.reduce(into: Set<IndexedCubeFace>()) {
      if self.isPlayable(side: $1.side, index: $1.index) {
        $0.insert($1)
      }
    }

    func hasPlayableWord(
      from face: IndexedCubeFace,
      selected: [IndexedCubeFace] = []
    ) -> Bool {
      let selected = selected + [face]
      let nextPlayableFaces = playableFaces.subtracting(selected).filter(face.isTouching)
      for nextFace in nextPlayableFaces {
        switch lookup(self.string(from: selected), .en) {
        case .some(.word):
          return true
        case .some(.prefix):
          if hasPlayableWord(from: nextFace, selected: selected) {
            return true
          }
        case .none:
          break
        }
      }
      return false
    }

    for face in playableFaces {
      if hasPlayableWord(from: face) { return true }
    }

    return false
  }
}
