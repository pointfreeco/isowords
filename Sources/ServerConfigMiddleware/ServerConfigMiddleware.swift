import Either
import HttpPipeline
import Prelude
import ServerConfig
import SharedModels

public func serverConfig(
  _ conn: Conn<StatusLineOpen, Void>
) -> IO<Conn<HeadersOpen, ServerConfig>> {
  conn.map(const(ServerConfig()))
    |> writeStatus(.ok)
}
