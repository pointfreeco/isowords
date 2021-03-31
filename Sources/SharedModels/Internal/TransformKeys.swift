
extension Dictionary {
  func transformKeys<NewKey>(_ f: (Key) -> NewKey) -> [NewKey: Value] {
    var result: [NewKey: Value] = [:]
    for (key, value) in self {
      result[f(key)] = value
    }
    return result
  }
}
