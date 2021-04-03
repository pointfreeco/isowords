import Either
import HttpPipeline
import Prelude
import ServerConfig
import SharedModels

public func changelog(
  _ conn: Conn<StatusLineOpen, Void>
) -> IO<Conn<HeadersOpen, Changelog>> {
  conn.map(const(Changelog.current))
    |> writeStatus(.ok)
}
