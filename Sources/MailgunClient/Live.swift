import Either
import Foundation
import UrlFormEncoding

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

extension MailgunClient {
  public static func live(
    apiKey: String,
    domain: String
  ) -> Self {
    let baseUrl = URL(string: "https://api.mailgun.net/")!

    return Self(
      sendEmail: { emailData in
        var components = URLComponents()
        components.path = "v3/\(domain)/messages"

        guard let url = components.url(relativeTo: baseUrl)
        else { return throwE(MailgunError()) }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = Data(
          urlFormEncode(
            value: [
              "to": emailData.to.rawValue,
              "from": emailData.from.rawValue,
              "subject": emailData.subject,
              "text": emailData.text,
            ]
          )
          .utf8
        )
        request.attachBasicAuth(username: "api", password: apiKey)

        return .init(
          run: .init { callback in
            URLSession.shared.dataTask(with: request) { data, response, error in
              if let data = data {
                do {
                  callback(.right(try JSONDecoder().decode(SendEmailResponse.self, from: data)))
                } catch {
                  callback(.left(error))
                }
              } else {
                callback(.left(error ?? MailgunError()))
              }
            }
            .resume()
          }
        )
      }
    )
  }
}

struct MailgunError: Error {}

extension URLRequest {
  mutating func attachBasicAuth(username: String = "", password: String = "") {
    self.allHTTPHeaderFields = self.allHTTPHeaderFields ?? [:]
    self.allHTTPHeaderFields?["Authorization"] =
      "Basic " + Data((username + ":" + password).utf8).base64EncodedString()
  }
}
