import Combine
import ComposableArchitecture

extension EffectPublisher where Failure == Never {
  public func prefix(id: AnyHashable, _ maxLength: Int) -> Self {
    Deferred { () -> AnyPublisher<Output, Failure> in
      if counts[id] ?? 0 > maxLength {
        return Empty().eraseToAnyPublisher()
      } else {
        counts[id, default: 0] += 1
        return self.eraseToAnyPublisher()
      }
    }
    .eraseToEffect()
  }
}

private var counts: [AnyHashable: Int] = [:]
