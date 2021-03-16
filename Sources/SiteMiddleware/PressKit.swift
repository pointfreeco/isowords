import Foundation
import HttpPipeline
import Prelude

func pressKitMiddleware(
  _ conn: Conn<StatusLineOpen, Void>
) -> IO<Conn<ResponseEnded, Data>> {
  conn
    |> writeStatus(.ok)
    >=> respond(html: html)
}

private let html = String(
  decoding: try! Data(
    contentsOf: Bundle.module.url(forResource: "press-kit", withExtension: "html")!
  ),
  as: UTF8.self
)
