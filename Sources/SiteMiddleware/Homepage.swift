import Foundation
import HttpPipeline
import Prelude

func homeMiddleware(
  _ conn: Conn<StatusLineOpen, Void>
) -> IO<Conn<ResponseEnded, Data>> {
  conn
    |> writeStatus(.ok)
    >=> respond(html: indexHtml)
}

private let indexHtml = String(
  decoding: try! Data(
    contentsOf: Bundle.module.url(forResource: "index", withExtension: "html")!
  ),
  as: UTF8.self
)
