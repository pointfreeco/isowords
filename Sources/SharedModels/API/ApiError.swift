import Foundation

public struct ApiError: Codable, Error, Equatable, LocalizedError {
  public let errorDump: String
  public let file: String
  public let line: UInt
  public let message: String

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
  }

  public var errorDescription: String? {
    self.message
  }
}
