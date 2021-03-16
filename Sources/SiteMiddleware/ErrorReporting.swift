import Either
import Foundation
import HttpPipeline
import Prelude

func errorReporting(
  _ middleware: @escaping Middleware<
    StatusLineOpen, ResponseEnded, RequireCurrentPlayerOutput, Data
  >
) -> Middleware<StatusLineOpen, ResponseEnded, RequireCurrentPlayerOutput, Data> {
  { conn in
    middleware(conn)
      .flatMap { finalConn in
        guard finalConn.response.status.rawValue >= 400
        else {
          return pure(finalConn)
        }

        let sanatizedRequestUrl = conn.request.url.flatMap { url -> URL? in
          var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
          components.queryItems = components.queryItems?.map {
            $0.name == "accessToken"
              ? .init(name: $0.name, value: "REDACTED")
              : $0
          }
          return components.url
        }

        return IO {
          DispatchQueue.global().async {
            _ = conn.data.mailgun.sendEmail(
              .init(
                from: "support@pointfree.co",
                to: "support@pointfree.co",
                subject: "API Error",
                text: """
                  Player: \(conn.data.player.id.rawValue)
                  Display name: \(conn.data.player.displayName ?? "None")

                  Request URL: \(sanatizedRequestUrl?.absoluteString ?? "None")
                  Request method: \(conn.request.httpMethod ?? "None")
                  Request headers: \(conn.request.allHTTPHeaderFields ?? [:])
                  Request body:
                  \(String(decoding: conn.request.httpBody ?? Data(), as: UTF8.self))

                  Response status: \(finalConn.response.status.rawValue)
                  Response body:
                  \(String(decoding: finalConn.response.body, as: UTF8.self))
                  """
              )
            )
            .run.perform()
          }

          return finalConn
        }
      }
  }
}
