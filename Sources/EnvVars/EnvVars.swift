import Foundation
import SnsClient
import Tagged

public struct EnvVars: Codable {
  public var appEnv: AppEnv
  public var awsAccessKeyId: String
  public var awsPlatformApplicationArn: PlatformArn
  public var awsPlatformApplicationSandboxArn: PlatformArn
  public var awsSecretKey: String
  public var baseUrl: URL
  public var databaseUrl: String
  public var mailgunApiKey: String
  public var mailgunDomain: String
  public var port: String
  var _secrets: String

  public init(
    appEnv: AppEnv = .development,
    awsAccessKeyId: String = "blank-aws-access-key-id",
    awsPlatformApplicationArn: PlatformArn = "arn:aws:sns:us-east-1:1234567890:app/APNS/deadbeef",
    awsPlatformApplicationSandboxArn: PlatformArn =
      "arn:aws:sns:us-east-1:1234567890:app/APNS_SANDBOX/deadbeef",
    awsSecretKey: String = "blank-aws-secret-key",
    baseUrl: URL = URL(string: "http://localhost:9876")!,
    databaseUrl: String = "postgres://isowords:@localhost:5432/isowords_development",
    mailgunApiKey: String = "blank-mailgun-api-key",
    mailgunDomain: String = "blank-mailgun-domain",
    port: String = "9876",
    secrets: String = "deadbeef"
  ) {
    self.appEnv = appEnv
    self.awsAccessKeyId = awsAccessKeyId
    self.awsPlatformApplicationArn = awsPlatformApplicationArn
    self.awsPlatformApplicationSandboxArn = awsPlatformApplicationSandboxArn
    self.awsSecretKey = awsSecretKey
    self.baseUrl = baseUrl
    self.databaseUrl = databaseUrl
    self.mailgunApiKey = mailgunApiKey
    self.mailgunDomain = mailgunDomain
    self.port = port
    self._secrets = secrets
  }

  private enum CodingKeys: String, CodingKey {
    case appEnv = "APP_ENV"
    case awsAccessKeyId = "AWS_ACCESS_KEY_ID"
    case awsPlatformApplicationArn = "AWS_PLATFORM_APPLICATION_ARN"
    case awsPlatformApplicationSandboxArn = "AWS_PLATFORM_APPLICATION_SANDBOX_ARN"
    case awsSecretKey = "AWS_SECRET_KEY"
    case databaseUrl = "DATABASE_URL"
    case baseUrl = "BASE_URL"
    case mailgunApiKey = "MAILGUN_API_KEY"
    case mailgunDomain = "MAILGUN_DOMAIN"
    case port = "PORT"
    case _secrets = "SECRETS"
  }

  public enum AppEnv: String, Codable {
    case development
    case production
    case staging
    case testing
  }

  public var secrets: [String] {
    self._secrets.split(separator: ",").map(String.init)
  }
}
