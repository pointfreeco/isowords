import Either
import Tagged

public typealias EndpointArn = Tagged<((), endpointArn: ()), String>
public typealias PlatformArn = Tagged<((), platformArn: ()), String>

public struct SnsClient {
  public var createPlatformEndpoint:
    (CreatePlatformRequest) -> EitherIO<Error, CreatePlatformEndpointResponse>
  public var deleteEndpoint: (EndpointArn) -> EitherIO<Error, DeleteEndpointResponse>
  public var _publish:
    (_ targetArn: EndpointArn, _ payload: AnyEncodable) -> EitherIO<Error, PublishResponse>

  public init(
    createPlatformEndpoint: @escaping (CreatePlatformRequest) -> EitherIO<
      Error, CreatePlatformEndpointResponse
    >,
    deleteEndpoint: @escaping (EndpointArn) -> EitherIO<Error, DeleteEndpointResponse>,
    publish: @escaping (_ targetArn: EndpointArn, _ payload: AnyEncodable) -> EitherIO<
      Error, PublishResponse
    >
  ) {
    self.createPlatformEndpoint = createPlatformEndpoint
    self.deleteEndpoint = deleteEndpoint
    self._publish = publish
  }

  public func publish<Content: Encodable>(
    targetArn: EndpointArn,
    payload: ApsPayload<Content>
  ) -> EitherIO<Error, PublishResponse> {
    self._publish(targetArn, AnyEncodable(payload))
  }

  public struct CreatePlatformRequest: Equatable {
    public let apnsToken: String
    public let platformApplicationArn: PlatformArn

    public init(
      apnsToken: String,
      platformApplicationArn: PlatformArn
    ) {
      self.apnsToken = apnsToken
      self.platformApplicationArn = platformApplicationArn
    }
  }
}
