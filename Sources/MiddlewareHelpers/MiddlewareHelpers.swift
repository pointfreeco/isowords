import EnvVars
import Foundation
import HttpPipeline
import Prelude

public func respondJson<A: Encodable>(
  envVars: EnvVars
) -> (Conn<HeadersOpen, A>) -> IO<Conn<ResponseEnded, Data>> {

  return { conn in
    let encoder = JSONEncoder()
    if envVars.appEnv == .testing {
      encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
    }
    let data = try! encoder.encode(conn.data)  // TODO: 400 on badly formed data. Show this operator on StatusLineOpen?

    return conn.map(const(data))
      |> writeHeader(.contentType(.json))
      >=> writeHeader(.contentLength(data.count))
      >=> closeHeaders
      >=> end
  }
}
