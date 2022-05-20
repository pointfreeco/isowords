import Foundation
import Parsing
import ServerRouter
import URLRouting

let date = { Date(timeIntervalSince1970: 1_234_567_890) }
let testRouter = ServerRouter(
  date: date,
  decoder: decoder,
  encoder: encoder,
  secrets: ["DEADBEEF"],
  sha256: testHash
)

func testHash(_ data: Data) -> Data {
  Data("\(data.hashValue)".utf8)
}

let encoder = { () -> JSONEncoder in
  let encoder = JSONEncoder()
  encoder.outputFormatting = .sortedKeys
  encoder.dateEncodingStrategy = .secondsSince1970
  return encoder
}()

let decoder = { () -> JSONDecoder in
  let decoder = JSONDecoder()
  decoder.dateDecodingStrategy = .secondsSince1970
  return decoder
}()
