import ServerTestHelpers

#if DEBUG
  extension MailgunClient {
    public static let failing = Self(
      sendEmail: { _ in
        .failing("\(Self.self).sendEmail is unimplemented")
      }
    )
  }
#endif

extension MailgunClient {
  public static let noop = Self(
    sendEmail: { _ in
      .init(
        run: .init {
          .right(
            .init(
              id: "mailgun:id",
              message: "Success"
            )
          )
        }
      )
    }
  )
}
