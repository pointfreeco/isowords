import ApplicativeRouter
import Foundation
import Prelude

func verifiedDataBody(
  date: @escaping () -> Date,
  require: Bool = true,
  secrets: [String],
  sha256: @escaping (Data) -> Data
) -> Router<Data> {
  (dataBody
    <%> header("X-Signature", opt(.base64))
    <%> queryParam("timestamp", opt(.int)))
    .map(.init(apply: { ($0, $1.0, $1.1) }, unapply: { ($0, ($1, $2)) }))
    .map(PartialIso.verifySignature(date: date, secrets: secrets, sha256: sha256))
    <|> (require ? .empty : dataBody)
}

extension PartialIso where A == (Data, Data?, Int?), B == Data {
  static func verifySignature(
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
