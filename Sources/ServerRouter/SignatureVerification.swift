import ApplicativeRouter
import Foundation
import Prelude
import Parsing
import _URLRouting

func verifiedDataBody(
  date: @escaping () -> Date,
  require: Bool = true,
  secrets: [String],
  sha256: @escaping (Data) -> Data
) -> AnyParserPrinter<URLRequestData, Data> {
  
  OneOf {
    Fail<URLRequestData, Data>()
//    Parse {
//      Body {
//        Conversion.init(
//          apply: { Data($0) },
//          unapply: ArraySlice.init
//        )
//      }
//      Headers {
//        Optionally {
//          Field("X-Signature", Base64Data())
//        }
//      }
//      Query {
//        Optionally {
//          Field("timestamp", Int.parser())
//        }
//      }
//    }
//    // TODO: should this be Routing(...) ?
//    // TODO: Or, should Pipe be a top-level parser type?
//    .map(._verifySignature(date: date, secrets: secrets, sha256: sha256))
//
//    if !require {
//      Body {
//        Parse(.data)
//      }
//    }
  }
  .eraseToAnyParserPrinter()
}

struct Base64Data: ParserPrinter {
  func parse(_ input: inout Substring) throws -> Data {
    guard let data = Data.init(base64Encoded: String(input))
    else {
      struct Base64Error: Error {}
      throw Base64Error()
    }
    input = ""
    return data
  }
  
  func print(_ output: Data, to input: inout Substring) {
    input.append(contentsOf: output.base64EncodedString())
  }
}

extension Conversion where Self == AnyConversion<(Data, Data?, Int?), Data> {
  static func _verifySignature(
    date: @escaping () -> Date,
    secrets: [String],
    sha256: @escaping (Data) -> Data
  ) -> Self {
    Self(
      apply: { data, signature, timestamp in
        guard
          let signature = signature,
          let timestamp = timestamp
        else { return nil }
        
        return isValidSignature(
          data: data,
          date: date,
          signature: signature,
          secrets: secrets,
          sha256: sha256,
          timestamp: timestamp
        )
        ? data
        : nil
      },
      unapply: { data in
        guard let firstSecret = secrets.first
        else { return nil }
        let timestamp = Int(date().timeIntervalSince1970)
        return signature(data: data, secret: firstSecret, sha256: sha256, timestamp: timestamp)
          .map { signature in (data, signature, timestamp) }
      }
    )
  }
}


func isValidSignature(
  data: Data,
  date: @escaping () -> Date,
  signature: Data,
  secrets: [String],
  sha256: @escaping (Data) -> Data,
  timestamp: Int
) -> Bool {
  signatures(data: data, secrets: secrets, sha256: sha256, timestamp: timestamp)
    .first(where: { $0 == signature }) != nil
    && abs(Int(date().timeIntervalSince1970) - timestamp) <= 20
}

func signatures(
  data: Data,
  secrets: [String],
  sha256: @escaping (Data) -> Data,
  timestamp: Int
) -> AnyCollection<Data> {
  AnyCollection(
    secrets.lazy.compactMap { secret in
      signature(data: data, secret: secret, sha256: sha256, timestamp: timestamp)
    }
  )
}

func signature(
  data: Data,
  secret: String,
  boundary: Data = Data("----".utf8),
  sha256: (Data) -> Data,
  timestamp: Int
) -> Data? {
  var data1 = data
  data1.append(boundary)
  data1.append(Data(secret.utf8))
  data1.append(boundary)
  data1.append(Data("\(timestamp)".utf8))
  return sha256(data1)
}
