import Combine
import CombineSchedulers

@propertyWrapper
public struct DateScheduler {
  public var wrappedValue: AnySchedulerOf<DispatchQueue>
  private let initialDate: Date
  private let initialUptime: UInt64

  public init(
    wrappedValue: AnySchedulerOf<DispatchQueue> = .main,
    now: Date = .init()
  ) {
    self.wrappedValue = wrappedValue
    self.initialDate = now
    self.initialUptime = self.wrappedValue.now.dispatchTime.uptimeNanoseconds
  }

  public var now: Date {
    self.initialDate.advanced(
      by: TimeInterval(self.wrappedValue.now.dispatchTime.uptimeNanoseconds - self.initialUptime)
        / TimeInterval(NSEC_PER_SEC)
    )
  }

  public var projectedValue: Self {
    self
  }
}
