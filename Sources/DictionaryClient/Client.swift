import NonEmpty
import SharedModels

public struct DictionaryClient {
  public var contains: (NonEmptyString, Language) -> Bool
  public var load: (Language) throws -> Bool
  public var lookup: ((NonEmptyString, Language) -> Lookup?)?
  public var randomCubes: (Language) -> Puzzle
  public var unload: (Language) -> Void

  public init(
    contains: @escaping (NonEmptyString, Language) -> Bool,
    load: @escaping (Language) throws -> Bool,
    lookup: ((NonEmptyString, Language) -> Lookup?)?,
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
