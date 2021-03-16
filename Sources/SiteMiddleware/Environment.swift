import ApplicativeRouter
import DatabaseClient
import DictionaryClient
import EnvVars
import Foundation
import MailgunClient
import Overture
import ServerRouter
import ServerRoutes
import SharedModels
import SnsClient
import VerifyReceiptMiddleware

public struct Environment {
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
  extension Environment {
    public static let unimplemented = Self(
      database: .failing,
      date: { fatalError() },
      dictionary: .failing,
      envVars: EnvVars(appEnv: .testing),
      itunes: .unimplemented,
      mailgun: .unimplemented,
      randomCubes: { fatalError() },
      router: .unimplemented,
      snsClient: .unimplemented
    )
  }
#endif
