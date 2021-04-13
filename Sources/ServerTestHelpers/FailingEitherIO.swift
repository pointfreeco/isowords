#if DEBUG
import Either
import XCTestDynamicOverlay

extension EitherIO where E == Error {
  public static func failing(_ title: String) -> Self {
    .init(
      run: .init {
        XCTFail("\(title): EitherIO is unimplemented")
        return .left(AnError())
      })
  }
}

public struct AnError: Error {}
#endif
