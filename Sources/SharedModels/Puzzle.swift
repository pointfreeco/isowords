public typealias Puzzle = Three<Three<Three<Cube>>>

extension Puzzle {
  public subscript(face: IndexedCubeFace) -> CubeFace {
    get {
      self[face.index][face.side]
    }
    set {
      self[face.index][face.side] = newValue
    }
  }
}
