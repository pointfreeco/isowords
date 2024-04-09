import ComposableArchitecture
import Foundation

// @SharedDependency(

// @Shared(.isLowPowerEnabled)// 🛑

// @SharedReader(.isLowPowerEnabled) var // read only
// @SharedReader(.savedGames) var // read only

public struct IsLowPowerModeEnabledKey: PersistenceKey, Hashable {
  public func load(initialValue: Bool?) -> Bool? {
    ProcessInfo.processInfo.isLowPowerModeEnabled
  }
  public func save(_ value: Value) {}
  public func subscribe(
    initialValue: Bool?,
    didSet: @escaping (Bool?) -> Void
  ) -> Shared<Bool>.Subscription {
    
    Task {
      var isOn = true
      while true {
        try await Task.sleep(for: .seconds(1))
        didSet(isOn)
        isOn.toggle()
      }
    }

    let token = NotificationCenter.default
      .addObserver(
        forName: .NSProcessInfoPowerStateDidChange,
        object: nil,
        queue: nil
      ) { _ in
        didSet(ProcessInfo.processInfo.isLowPowerModeEnabled)
      }
    return Shared.Subscription {
      NotificationCenter.default.removeObserver(token)
    }
  }
}

extension PersistenceKey where Self == IsLowPowerModeEnabledKey {
  public static var isLowPowerEnabled: Self {
    IsLowPowerModeEnabledKey()
  }
}
