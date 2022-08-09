public final class AsyncStreamProducer<Element> {
  public private(set) var continuation = Continuation()

  public init() {}

  public var stream: AsyncStream<Element> {
    AsyncStream { self.continuation.continuations.append($0) }
  }

  public struct Continuation {
    fileprivate var continuations: [AsyncStream<Element>.Continuation] = []

    public func yield(_ value: Element) {
      for continuation in self.continuations {
        continuation.yield(value)
      }
    }

    public func yield(with result: Result<Element, Never>) {
      for continuation in self.continuations {
        continuation.yield(with: result)
      }
    }

    public func finish() {
      for continuation in self.continuations {
        continuation.finish()
      }
    }
  }
}
