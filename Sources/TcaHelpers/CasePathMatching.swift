import CasePaths

extension CasePath {
  public func isMatching(_ value: Root) -> Bool {
    self.extract(from: value) != nil
  }

  public func isNotMatching(_ value: Root) -> Bool {
    self.extract(from: value) == nil
  }
}
