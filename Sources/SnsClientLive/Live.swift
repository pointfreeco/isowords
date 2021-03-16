import Either
import Foundation
@_exported import SnsClient
import SwiftAWSSignatureV4

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

extension SnsClient {
  public static func live(
    accessKeyId: String,
    secretKey: String,
    region: String = "us-east-1",
    version: String = "2010-03-31"
  ) -> Self {

    let account = AWSAccount(
      serviceName: "sns",
      region: region,
      accessKeyID: accessKeyId,
      secretAccessKey: secretKey
    )

    return Self(
      createPlatformEndpoint: {
        //https://docs.aws.amazon.com/sns/latest/api/API_CreatePlatformEndpoint.html
        request(
          CreatePlatformEndpointResponse.self,
          action: "CreatePlatformEndpoint",
          queryParameters: [
            "PlatformApplicationArn": $0.platformApplicationArn.rawValue,
            "Token": $0.apnsToken,
          ],
          version: version,
          account: account
        )
      },
      deleteEndpoint: { arn in
        //https://docs.aws.amazon.com/sns/latest/api/API_DeleteEndpoint.html
        request(
          DeleteEndpointResponse.self,
          action: "DeleteEndpoint",
          queryParameters: ["EndpointArn": arn.rawValue],
          version: version,
          account: account
        )
      },
      publish: { targetArn, payload in
        //https://docs.aws.amazon.com/sns/latest/api/API_Publish.html
        let payloadJsonString: String
        let fullPayload: String
        do {
          payloadJsonString = String(
            decoding: try JSONEncoder().encode(payload),
            as: UTF8.self
          )
          fullPayload = String(
            decoding: try JSONSerialization.data(
              withJSONObject: [
                "APNS": payloadJsonString,
                "APNS_SANDBOX": payloadJsonString,
              ]
            ),
            as: UTF8.self
          )
        } catch {
          return throwE(error)
        }

        return request(
          PublishResponse.self,
          action: "Publish",
          queryParameters: [
            "Message": fullPayload,
            "TargetArn": targetArn.rawValue,
            "MessageStructure": "json",
          ],
          version: version,
          account: account
        )
      }
    )
  }
}

private func request<M: Decodable>(
  _ model: M.Type,
  action: String,
  queryParameters: [String: String],
  version: String,
  account: AWSAccount
) -> EitherIO<Error, M> {

  let queryParameters = [
    "Action": "\(action)",
    "Version": "\(version)",
  ]
  .merging(queryParameters, uniquingKeysWith: { $1 })

  let base = "sns.\(account.region).amazonaws.com"
  var request = URLRequest(url: URL(string: "https://\(base)")!)
  request.httpMethod = "POST"
  request.setValue("application/json", forHTTPHeaderField: "Content-Type")
  request.setValue(base, forHTTPHeaderField: "Host")
  request.setValue("application/json", forHTTPHeaderField: "Accept")
  request.sign(for: account, urlQueryParams: queryParameters, signPayload: true)

  return .init(
    run: .init { callback in
      URLSession.shared.dataTask(with: request) { data, response, error in
        if let data = data {
          do {
            // First try decoding data into the model
            callback(.right(try JSONDecoder().decode(M.self, from: data)))
          } catch {
            let modelDecodingError = error
            do {
              // If that fails try decoding data into AwsError
              callback(.left(try JSONDecoder().decode(AwsError.self, from: data)))
            } catch {
              // If all of that fails return the error from the model decoding,
              // not the error decoding.
              callback(.left(modelDecodingError))
            }
          }
        } else if let error = error {
          callback(.left(error))
        } else {
          callback(.left(GenericAwsError()))
        }
      }
      .resume()
    }
  )
}

private struct GenericAwsError: Error {}
