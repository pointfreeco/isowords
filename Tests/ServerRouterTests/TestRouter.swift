import Foundation
import Parsing
import ServerRouter
import _URLRouting

extension Parser where Input == URLRequestData {
  func match(request: URLRequest) -> Output? {
    guard var data = URLRequestData(request: request)
    else { return nil }
    return self.parse(&data)
  }
  
  func match(string: String) -> Output? {
    guard var data = URLRequestData(request: URLRequest.init(url: URL(string: string)!))
    else { return nil }
    return self.parse(&data)
  }
}

extension Printer where Input == URLRequestData {
  func request(for route: Output, base: URL? = nil) -> URLRequest? {
    guard var request = self.print(route).flatMap(URLRequest.init(data:))
    else { return nil }
    
    if
      let base = base,
      let requestURL = request.url
    {
      request.url = URL.init(string: base.absoluteString + requestURL.absoluteString)
    }
    
    return request
  }
}

let date = { Date(timeIntervalSince1970: 1_234_567_890) }
let testRouter = router(
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
