import SharedModels

public struct DictionaryClient {
  public var contains: (String, Language) -> Bool
  public var load: (Language) throws -> Bool
  public var lookup: ((String, Language) -> Lookup?)?
  public var randomCubes: (Language) -> Puzzle
  public var unload: (Language) -> Void

  public init(
    contains: @escaping (String, Language) -> Bool,
    load: @escaping (Language) throws -> Bool,
    lookup: ((String, Language) -> Lookup?)?,
    randomCubes: @escaping (Language) -> Puzzle,
    unload: @escaping (Language) -> Void
  ) {
    self.contains = contains
    self.lookup = lookup
    self.load = load
    self.randomCubes = randomCubes
    self.unload = unload
  }

  public enum Lookup: Equatable {
    case prefix
    case word
  }
}
