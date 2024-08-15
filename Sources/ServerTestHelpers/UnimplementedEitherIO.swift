#if DEBUG
  import Either
  import IssueReporting

  extension EitherIO where E == Error {
    public static func unimplemented(_ message: String) -> Self {
      let message = "Unimplemented\(message.isEmpty ? "" : ": \(message)")"
      return .init(
        run: .init {
          XCTFail(message)
          return .left(AnError(message: message))
        })
    }
  }

  public struct AnError: Error {
    let message: String
  }

  extension EitherIO {
    public init(value: A) {
      self = .init(run: .init { .right(value) })
    }
  }
#endif
