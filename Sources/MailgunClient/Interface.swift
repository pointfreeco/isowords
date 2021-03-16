import Either
import Tagged

public typealias EmailAddress = Tagged<((), email: ()), String>

public struct MailgunClient {
  public var sendEmail: (EmailData) -> EitherIO<Error, SendEmailResponse>
}

public struct EmailData {
  public var from: EmailAddress
  public var to: EmailAddress
  public var subject: String
  public var text: String

  public init(
    from: EmailAddress,
    to: EmailAddress,
    subject: String,
    text: String
  ) {
    self.from = from
    self.to = to
    self.subject = subject
    self.text = text
  }
}

public struct SendEmailResponse: Decodable {
  public typealias Id = Tagged<Self, String>

  public let id: Id
  public let message: String

  public init(id: Id, message: String) {
    self.id = id
    self.message = message
  }
}
