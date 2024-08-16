import DatabaseClient
import DependenciesMacros
import DictionaryClient
import EnvVars
import Foundation
import MailgunClient
import Overture
import ServerConfig
import ServerRouter
import SharedModels
import SnsClient
import URLRouting
import VerifyReceiptMiddleware

@DependencyClient
public struct ServerEnvironment {
  public var changelog: () -> Changelog = { .current }
  public var database: DatabaseClient
  public var date: () -> Date = { Date() }
  public var dictionary: DictionaryClient
  public var envVars: EnvVars
  public var itunes: ItunesClient
  public var mailgun: MailgunClient
  public var randomCubes: () -> ArchivablePuzzle = { .mock }
  public var router: ServerRouter
  public var snsClient: SnsClient
}

#if DEBUG
  import IssueReporting

  extension ServerEnvironment {
    public static let testValue = Self(
      database: .testValue,
      dictionary: .testValue,
      envVars: EnvVars(appEnv: .testing),
      itunes: .testValue,
      mailgun: .testValue,
      router: .testValue,
      snsClient: .testValue
    )
  }
#endif
