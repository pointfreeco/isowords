import DependenciesMacros
import SharedModels

@DependencyClient
public struct DictionaryClient {
  public var contains: (String, Language) -> Bool = { _, _ in false }
  public var load: (Language) throws -> Bool
  public var lookup: ((String, Language) -> Lookup?)?
  public var randomCubes: (Language) -> Puzzle = { _ in .mock }
  public var unload: (Language) -> Void

  public enum Lookup: Equatable {
    case prefix
    case word
  }
}
