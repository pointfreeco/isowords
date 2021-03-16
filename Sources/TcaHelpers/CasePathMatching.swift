import CasePaths

public func ~= <Root, Value>(pattern: CasePath<Root, Value>, value: Root) -> Bool {
  pattern.extract(from: value) != nil
}

extension CasePath {
  public func isMatching(_ value: Root) -> Bool {
    self.extract(from: value) != nil
  }

  public func isNotMatching(_ value: Root) -> Bool {
    self.extract(from: value) == nil
  }
}
