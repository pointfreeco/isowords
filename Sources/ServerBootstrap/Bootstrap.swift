import Backtrace
import Crypto
import DatabaseLive
import DictionarySqliteClient
import Either
import EnvVars
import Foundation
import NIO
import Overture
import PostgresKit
import Prelude
import PuzzleGen
import ServerConfig
import ServerRouter
import SharedModels
import SiteMiddleware
import SnsClientLive

public func bootstrap(eventLoopGroup: EventLoopGroup) -> EitherIO<Error, ServerEnvironment> {
  Backtrace.install()

  return EitherIO.debug(prefix: "⏳ Bootstrapping isowords...")
    .flatMap(
      const(prepareEnvironment(eventLoopGroup: eventLoopGroup))
    )
    .flatMap(fireAndForget(connectToPostgres(eventLoopGroup: eventLoopGroup)))
    .flatMap(fireAndForget(.debug(prefix: "✅ isowords Bootstrapped!")))
}

private func prepareEnvironment(eventLoopGroup: EventLoopGroup) -> EitherIO<
  Error, ServerEnvironment
> {
  EitherIO.debug(prefix: "  ⏳ Loading environment...")
    .flatMap(loadEnvVars)
    .flatMap(loadEnvironment(eventLoopGroup: eventLoopGroup))
    .flatMap(bootstrapDictionary(environment:))
    .flatMap(fireAndForget(.debug(prefix: "  ✅ Loaded!")))
}

private let loadEnvVars = { () -> EitherIO<Error, EnvVars> in
  let envFilePath = URL(fileURLWithPath: #file)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .appendingPathComponent(".iso-env")

  let decoder = JSONDecoder()
  let encoder = JSONEncoder()

  let defaultEnvVars = EnvVars()
  let defaultEnvVarDict =
    (try? encoder.encode(defaultEnvVars))
    .flatMap { try? decoder.decode([String: String].self, from: $0) }
    ?? [:]

  let localEnvVarDict =
    (try? Data(contentsOf: envFilePath))
    .flatMap { try? decoder.decode([String: String].self, from: $0) }
    ?? [:]

  let envVarDict =
    defaultEnvVarDict
    .merging(localEnvVarDict, uniquingKeysWith: { $1 })
    .merging(ProcessInfo.processInfo.environment, uniquingKeysWith: { $1 })

  let envVars =
    (try? JSONSerialization.data(withJSONObject: envVarDict))
    .flatMap { try? decoder.decode(EnvVars.self, from: $0) }
    ?? defaultEnvVars

  return pure(envVars)
}

private func loadEnvironment(eventLoopGroup: EventLoopGroup) -> (EnvVars) -> EitherIO<
  Error, ServerEnvironment
> {
  { envVars in
    return pure(
      ServerEnvironment(
        changelog: { Changelog.current },
        database: .live(
          pool: .init(
            source: PostgresConnectionSource(
              configuration: update(PostgresConfiguration(url: envVars.databaseUrl)!) {
                if envVars.databaseUrl.contains("amazonaws.com") {
                  $0.tlsConfiguration = update(.clientDefault) {
                    $0.certificateVerification = .none
                  }
                }
              }
            ),
            on: eventLoopGroup
          )
        ),
        date: Date.init,
        dictionary: .sqlite(),
        envVars: envVars,
        itunes: .live,
        mailgun: .live(
          apiKey: envVars.mailgunApiKey,
          domain: envVars.mailgunDomain
        ),
        randomCubes: { .init(cubes: randomCubes(for: isowordsLetter).run()) },
        router: ServerRouter(
          date: Date.init,
          decoder: decoder,
          encoder: encoder,
          secrets: envVars.secrets,
          sha256: { Data(SHA256.hash(data: $0)) }
        ),
        snsClient: .live(
          accessKeyId: envVars.awsAccessKeyId,
          secretKey: envVars.awsSecretKey
        )
      )
    )
  }
}

private func bootstrapDictionary(environment: ServerEnvironment) -> EitherIO<
  Error, ServerEnvironment
> {
  .init(
    run: .init {
      do {
        try Language.allCases.forEach { language in
          _ = try environment.dictionary.load(language)
        }
        return .right(environment)
      } catch {
        return .left(error)
      }
    }
  )
}

private func connectToPostgres(
  eventLoopGroup: EventLoopGroup
) -> (ServerEnvironment) -> EitherIO<Error, Void> {
  { environment in
    EitherIO.debug(prefix: "  ⏳ Connecting to PostgreSQL")
      .flatMap { _ -> EitherIO<Error, Void> in
        #if DEBUG
          if environment.envVars.appEnv == .staging || environment.envVars.appEnv == .production {
            return EitherIO.debug(prefix: "  ↪️ Skipping migrations")
          }
        #endif
        return environment.database.migrate()
      }
      .catch { EitherIO.debug(prefix: "  ❌ Error! \($0)").flatMap(const(throwE($0))) }
      .retry(maxRetries: 999_999, backoff: const(.seconds(1)))
      .flatMap(const(.debug(prefix: "  ✅ Connected to PostgreSQL!")))
      .flatMap(const(stepDivider))
  }
}

private let stepDivider = EitherIO.debug(prefix: "  -----------------------------")

extension EitherIO where A == Void, E == Error {
  static func debug(prefix: String) -> EitherIO {
    EitherIO(
      run: IO {
        print(prefix)
        return .right(())
      })
  }
}

private func fireAndForget<A, E: Error>(
  _ b: EitherIO<E, Void>
) -> (A) -> EitherIO<E, A> {
  return { a in
    b.flatMap { _ in
      pure(a)
    }
  }
}

private func fireAndForget<A, E: Error>(
  _ f: @escaping (A) -> EitherIO<E, Void>
) -> (A) -> EitherIO<E, A> {
  return { a in
    f(a).flatMap { _ in
      pure(a)
    }
  }
}

private let encoder = { () -> JSONEncoder in
  let encoder = JSONEncoder()
  encoder.dateEncodingStrategy = .secondsSince1970
  return encoder
}()

private let decoder = { () -> JSONDecoder in
  let decoder = JSONDecoder()
  decoder.dateDecodingStrategy = .secondsSince1970
  return decoder
}()
