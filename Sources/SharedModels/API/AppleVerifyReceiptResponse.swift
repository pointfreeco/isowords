import Foundation

public struct AppleVerifyReceiptResponse: Equatable, Sendable {
  public var environment: Environment?
  public var isRetryable: Bool
  public var receipt: Receipt
  public var status: Int

  public enum Environment: String, Codable, Equatable, Sendable {
    case sandbox = "Sandbox"
    case production = "Production"
  }

  public struct Receipt: Equatable, Sendable {
    public var appItemId: Int
    public var applicationVersion: String
    public var bundleId: String
    public var inApp: [InApp]
    public var originalPurchaseDate: Date
    public var receiptCreationDate: Date
    public var requestDate: Date

    public struct InApp: Equatable, Sendable {
      public var originalPurchaseDate: Date
      public var originalTransactionId: String
      public var productId: String
      public var purchaseDate: Date
      public var quantity: Int
      public var transactionId: String
    }
  }
}

extension AppleVerifyReceiptResponse: Codable {
  enum CodingKeys: String, CodingKey {
    case environment
    case isRetryable = "is-retryable"
    case receipt
    case status
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.environment = try container.decodeIfPresent(Environment.self, forKey: .environment)
    self.isRetryable = try container.decodeIfPresent(Bool.self, forKey: .isRetryable) ?? false
    self.receipt = try container.decode(AppleVerifyReceiptResponse.Receipt.self, forKey: .receipt)
    self.status = try container.decode(Int.self, forKey: .status)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(self.environment, forKey: .environment)
    try container.encode(self.isRetryable, forKey: .isRetryable)
    try container.encode(self.receipt, forKey: .receipt)
    try container.encode(self.status, forKey: .status)
  }
}

extension AppleVerifyReceiptResponse.Receipt: Codable {
  enum CodingKeys: String, CodingKey {
    case appItemId = "app_item_id"
    case applicationVersion = "application_version"
    case bundleId = "bundle_id"
    case inApp = "in_app"
    case originalPurchaseDate = "original_purchase_date_ms"
    case receiptCreationDate = "receipt_creation_date_ms"
    case requestDate = "request_date_ms"
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.appItemId = try container.decode(Int.self, forKey: .appItemId)
    self.applicationVersion = try container.decode(String.self, forKey: .applicationVersion)
    self.bundleId = try container.decode(String.self, forKey: .bundleId)
    self.inApp = try container.decode([InApp].self, forKey: .inApp)
    self.originalPurchaseDate = try container.decodeMs(forKey: .originalPurchaseDate)
    self.receiptCreationDate = try container.decodeMs(forKey: .receiptCreationDate)
    self.requestDate = try container.decodeMs(forKey: .requestDate)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(self.appItemId, forKey: .appItemId)
    try container.encode(self.applicationVersion, forKey: .applicationVersion)
    try container.encode(self.bundleId, forKey: .bundleId)
    try container.encode(self.inApp, forKey: .inApp)
    try container.encodeStringMs(self.originalPurchaseDate, forKey: .originalPurchaseDate)
    try container.encodeStringMs(self.receiptCreationDate, forKey: .receiptCreationDate)
    try container.encodeStringMs(self.requestDate, forKey: .requestDate)
  }
}

extension AppleVerifyReceiptResponse.Receipt.InApp: Codable {
  enum CodingKeys: String, CodingKey {
    case originalPurchaseDate = "original_purchase_date_ms"
    case originalTransactionId = "original_transaction_id"
    case productId = "product_id"
    case purchaseDate = "purchase_date_ms"
    case quantity = "quantity"
    case transactionId = "transaction_id"
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.originalPurchaseDate = try container.decodeMs(forKey: .originalPurchaseDate)
    self.originalTransactionId = try container.decode(String.self, forKey: .originalTransactionId)
    self.productId = try container.decode(String.self, forKey: .productId)
    self.purchaseDate = try container.decodeMs(forKey: .purchaseDate)
    self.quantity = try container.decodeIntFromString(forKey: .quantity)
    self.transactionId = try container.decode(String.self, forKey: .transactionId)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encodeStringMs(self.originalPurchaseDate, forKey: .originalPurchaseDate)
    try container.encode(self.originalTransactionId, forKey: .originalTransactionId)
    try container.encode(self.productId, forKey: .productId)
    try container.encodeStringMs(self.purchaseDate, forKey: .purchaseDate)
    try container.encodeIntToString(self.quantity, forKey: .quantity)
    try container.encode(self.transactionId, forKey: .transactionId)
  }
}

extension KeyedDecodingContainer {
  func decodeMs(forKey key: KeyedDecodingContainer<K>.Key) throws -> Date {
    guard let ms = try TimeInterval(self.decode(String.self, forKey: key))
    else {
      throw DecodingError.dataCorruptedError(
        forKey: key,
        in: self,
        debugDescription: "Date should be a string holding milliseconds since 1970."
      )
    }
    return Date(timeIntervalSince1970: ms / 1000)
  }

  func decodeIntFromString(forKey key: KeyedDecodingContainer<K>.Key) throws -> Int {
    guard let int = try Int(self.decode(String.self, forKey: key))
    else {
      throw DecodingError.dataCorruptedError(
        forKey: key,
        in: self,
        debugDescription: "String should be convertible to an integer."
      )
    }
    return int
  }
}

extension KeyedEncodingContainer {
  mutating func encodeStringMs(_ value: Date, forKey key: KeyedEncodingContainer<K>.Key) throws {
    try self.encode(String(Int(value.timeIntervalSince1970 * 1_000)), forKey: key)
  }

  mutating func encodeIntToString(_ value: Int, forKey key: KeyedEncodingContainer<K>.Key) throws {
    try self.encode(String(value), forKey: key)
  }
}

let jsonDecoder = JSONDecoder()

#if DEBUG
  extension AppleVerifyReceiptResponse {
    public static let mock = Self(
      environment: .production,
      isRetryable: true,
      receipt: .init(
        appItemId: 1,
        applicationVersion: "1",
        bundleId: "co.pointfree.isowords",
        inApp: [
          .init(
            originalPurchaseDate: .init(timeIntervalSinceReferenceDate: 1_234_567_890),
            originalTransactionId: "deadbeef",
            productId: "full-game",
            purchaseDate: .init(timeIntervalSinceReferenceDate: 1_234_567_890),
            quantity: 1,
            transactionId: "deadbeef"
          )
        ],
        originalPurchaseDate: .init(timeIntervalSinceReferenceDate: 1_234_567_890),
        receiptCreationDate: .init(timeIntervalSinceReferenceDate: 1_234_567_890),
        requestDate: .init(timeIntervalSinceReferenceDate: 1_234_567_890)
      ),
      status: 0
    )
  }
#endif
