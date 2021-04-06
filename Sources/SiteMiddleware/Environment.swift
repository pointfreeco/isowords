import ApplicativeRouter
import DatabaseClient
import DictionaryClient
import EnvVars
import Foundation
import MailgunClient
import Overture
import ServerConfig
import ServerRouter
import SharedModels
import SnsClient
import VerifyReceiptMiddleware

public struct Environment {
  public var changelog: () -> Changelog
  public var database: DatabaseClient
  public var date: () -> Date
  public var dictionary: DictionaryClient
  public var itunes: ItunesClient
  public var envVars: EnvVars
  public var mailgun: MailgunClient
  public var randomCubes: () -> ArchivablePuzzle
  public var router: Router<ServerRoute>
  public var snsClient: SnsClient

  public init(
    changelog: @escaping () -> Changelog,
    database: DatabaseClient,
    date: @escaping () -> Date,
    dictionary: DictionaryClient,
    envVars: EnvVars,
    itunes: ItunesClient,
    mailgun: MailgunClient,
    randomCubes: @escaping () -> ArchivablePuzzle,
    router: Router<ServerRoute>,
    snsClient: SnsClient
  ) {
    self.changelog = changelog
    self.database = database
    self.date = date
    self.dictionary = dictionary
    self.envVars = envVars
    self.itunes = itunes
    self.mailgun = mailgun
    self.randomCubes = randomCubes
    self.router = router
    self.snsClient = snsClient
  }
}

#if DEBUG
import XCTestDynamicOverlay

  extension Environment {
    public static let unimplemented = Self(
      changelog: {
        XCTFail("changelog is unimplemented.")
        return .current
      },
      database: .failing,
      date: {
        XCTFail("date is unimplemented.")
        return .init()
      },
      dictionary: .failing,
      envVars: EnvVars(appEnv: .testing),
      itunes: .unimplemented,
      mailgun: .unimplemented,
      randomCubes: {
        XCTFail("randomCubes is unimplemented.")
        return .mock
      },
      router: .unimplemented,
      snsClient: .unimplemented
    )
  }
#endif
