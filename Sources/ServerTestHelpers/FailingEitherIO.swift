#if DEBUG
import Either
import XCTestDynamicOverlay

extension EitherIO where E == Error {
  public static func failing(_ title: String) -> Self {
    .init(
      run: .init {
        XCTFail("\(title): EitherIO is unimplemented")
        return .left(AnError(message: "\(title): EitherIO is unimplemented"))
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
