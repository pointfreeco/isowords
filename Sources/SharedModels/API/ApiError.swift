import Foundation

public struct ApiError: Codable, Error, Equatable, LocalizedError {
  public let errorDump: String
  public let file: String
  public let line: UInt
  public let message: String
  public var reason: FailureReason?

  public init(
    error: Error,
    file: StaticString = #fileID,
    line: UInt = #line
  ) {
    var string = ""
    dump(error, to: &string)
    self.errorDump = string
    self.file = String(describing: file)
    self.line = line
    self.message = error.localizedDescription  // TODO: separate user facing from debug facing messages?
    if NSURLErrorConnectionFailureCodes.contains((error as NSError).code) {
      self.reason = .offline
    }
  }

  public var errorDescription: String? {
    self.message
  }
  
  public var failureReason: String? {
    self.reason?.description
  }
  
  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.message == rhs.message && lhs.errorDump == rhs.errorDump
  }
}

private let NSURLErrorConnectionFailureCodes: [Int] = [
  NSURLErrorCannotFindHost, /// Error Code: ` -1003`
  NSURLErrorCannotConnectToHost, /// Error Code: ` -1004`
  NSURLErrorNetworkConnectionLost, /// Error Code: ` -1005`
  NSURLErrorNotConnectedToInternet, /// Error Code: ` -1009`
  NSURLErrorSecureConnectionFailed /// Error Code: ` -1200`
]

public enum FailureReason: CustomStringConvertible, Equatable, Codable {
  case offline
  
  public var description: String {
    switch self {
    case .offline:
      return "Connection unavailable"
    }
  }
}
