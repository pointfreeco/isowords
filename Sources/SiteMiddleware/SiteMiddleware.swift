import AppSiteAssociationMiddleware
import ApplicativeRouterHttpPipelineSupport
import DemoMiddleware
import Foundation
import HttpPipeline
import MiddlewareHelpers
import Prelude
import ServerConfig
import ServerRouter
import ShareGameMiddleware
import SharedModels
import Tagged

public func siteMiddleware(
  environment: Environment
) -> Middleware<StatusLineOpen, ResponseEnded, Prelude.Unit, Data> {
  requireHerokuHttps(allowedInsecureHosts: allowedInsecureHosts)
    <<< route(
      router: environment.router,
      notFound: writeStatus(.notFound) >=> respond(json: "{}")
    )
    <| render(environment: environment)
}

private func render(
  environment: Environment
) -> Middleware<StatusLineOpen, ResponseEnded, ServerRoute, Data> {
  { conn in
    let route = conn.data

    switch route {
    case let .api(api):
      return conn.map(
        const(
          .init(
            api: api,
            database: environment.database,
            dictionary: environment.dictionary,
            envVars: environment.envVars,
            isDebug: api.isDebug,
            itunes: environment.itunes,
            mailgun: environment.mailgun,
            randomCubes: environment.randomCubes,
            router: environment.router,
            snsClient: environment.snsClient
          )
        )
      )
        |> apiMiddleware

    case .appSiteAssociation:
      return conn.map(const(()))
        |> appSiteAssociationMiddleware
        >=> respondJson(envVars: environment.envVars)

    case .appStore:
      return conn.map(const(()))
        |> redirect(to: ServerConfig().appStoreUrl.absoluteString)

    case let .authenticate(request):
      return conn.map(
        const(
          .init(
            database: environment.database,
            deviceId: request.deviceId,
            displayName: request.displayName,
            gameCenterLocalPlayerId: request.gameCenterLocalPlayerId,
            timeZone: request.timeZone
          )
        )
      )
        |> authenticateMiddleware
        >=> respondJson(envVars: environment.envVars)

    case let .demo(.submitGame(request)):
      return conn.map(
        const(
          SubmitDemoGameRequest(
            database: environment.database,
            dictionary: environment.dictionary,
            submitRequest: request
          )
        )
      )
        |> submitDemoGameMiddleware
        >=> respondJson(envVars: environment.envVars)

    case .download:
      return conn.request.allHTTPHeaderFields?["User-Agent"]?.contains("Mobile") == true
        ? (conn.map(const(()))
          |> redirect(to: ServerConfig().appStoreUrl.absoluteString))
        : (conn.map(const(()))
          |> redirect(to: "/"))

    case .home:
      return conn.map(const(()))
        |> homeMiddleware

    case .pressKit:
      return conn.map(const(()))
        |> pressKitMiddleware

    case .privacyPolicy:
      return conn.map(const(()))
        |> privacyPolicyMiddleware

    case let .sharedGame(.show(code)):
      return conn.map(const(.init(code: code, router: environment.router)))
        |> showSharedGameMiddleware
    }
  }
}

private let allowedInsecureHosts: [String] = [
  "127.0.0.1",
  "0.0.0.0",
  "localhost",
  "",
]
