import Foundation

extension UUID {
  public static let accessToken = Self(uuidString: "deadbeef-dead-beef-dead-0acce55704e4")!
  public static let dailyChallengeId = Self(uuidString: "deadbeef-dead-beef-dead-da117c4a1132")!
  public static let deadbeef = Self(uuidString: "deadbeef-dead-beef-dead-beefdeadbeef")!
  public static let deviceId = Self(uuidString: "de71ce00-dead-beef-dead-beefdeadbeef")!

  public static var incrementing: () -> UUID {
    var uuid = 0
    return {
      defer { uuid += 1 }
      return Self(uuidString: "00000000-0000-0000-0000-\(String(format: "%012x", uuid))")!
    }
  }
}
