import Combine
import ComposableArchitecture
import StoreKit

public struct StoreKitClient {
  @available(*, deprecated) public var addPayment: (SKPayment) -> Effect<Never, Never>
  public var addPaymentAsync: @Sendable (SKPayment) async -> Void
  public var appStoreReceiptURL: @Sendable () -> URL?
  public var isAuthorizedForPayments: @Sendable () -> Bool
  @available(*, deprecated) public var fetchProducts: (Set<String>) -> Effect<ProductsResponse, Error>
  public var fetchProductsAsync: @Sendable (Set<String>) async throws -> ProductsResponse
  @available(*, deprecated) public var finishTransaction: (PaymentTransaction) -> Effect<Never, Never>
  public var finishTransactionAsync: @Sendable (PaymentTransaction) async -> Void
  @available(*, deprecated) public var observer: Effect<PaymentTransactionObserverEvent, Never>
  public var observerAsync: @Sendable () -> AsyncStream<PaymentTransactionObserverEvent>
  @available(*, deprecated) public var requestReview: () -> Effect<Never, Never>
  public var requestReviewAsync: @Sendable () async -> Void
  @available(*, deprecated) public var restoreCompletedTransactions: () -> Effect<Never, Never>
  public var restoreCompletedTransactionsAsync: @Sendable () async -> Void

  public enum PaymentTransactionObserverEvent: Equatable {
    case removedTransactions([PaymentTransaction])
    case restoreCompletedTransactionsFailed(NSError)
    case restoreCompletedTransactionsFinished(transactions: [PaymentTransaction])
    case updatedTransactions([PaymentTransaction])
  }

  public struct ProductsResponse: Equatable {
    public var invalidProductIdentifiers: [String]
    public var products: [Product]

    public init(
      invalidProductIdentifiers: [String],
      products: [Product]
    ) {
      self.invalidProductIdentifiers = invalidProductIdentifiers
      self.products = products
    }
  }

  public struct Product: Equatable {
    public var downloadContentLengths: [NSNumber]
    public var downloadContentVersion: String
    public var isDownloadable: Bool
    public var localizedDescription: String
    public var localizedTitle: String
    public var price: NSDecimalNumber
    public var priceLocale: Locale
    public var productIdentifier: String

    public init(
      downloadContentLengths: [NSNumber],
      downloadContentVersion: String,
      isDownloadable: Bool,
      localizedDescription: String,
      localizedTitle: String,
      price: NSDecimalNumber,
      priceLocale: Locale,
      productIdentifier: String
    ) {
      self.downloadContentLengths = downloadContentLengths
      self.downloadContentVersion = downloadContentVersion
      self.isDownloadable = isDownloadable
      self.localizedDescription = localizedDescription
      self.localizedTitle = localizedTitle
      self.price = price
      self.priceLocale = priceLocale
      self.productIdentifier = productIdentifier
    }
  }

  public struct PaymentTransaction: Equatable {
    public var error: NSError?
    public var _original: () -> PaymentTransaction?
    public var payment: Payment
    public var rawValue: SKPaymentTransaction?
    public var transactionDate: Date?
    public var transactionIdentifier: String?
    public var transactionState: SKPaymentTransactionState

    public init(
      error: NSError?,
      original: @escaping @autoclosure () -> PaymentTransaction?,
      payment: Payment,
      rawValue: SKPaymentTransaction?,
      transactionDate: Date?,
      transactionIdentifier: String?,
      transactionState: SKPaymentTransactionState
    ) {
      self.error = error
      self._original = original
      self.payment = payment
      self.rawValue = rawValue
      self.transactionDate = transactionDate
      self.transactionIdentifier = transactionIdentifier
      self.transactionState = transactionState
    }

    public var original: PaymentTransaction? { self._original() }

    public static func == (lhs: Self, rhs: Self) -> Bool {
      lhs.error == rhs.error
        && lhs.original == rhs.original
        && lhs.payment == rhs.payment
        && lhs.transactionDate == rhs.transactionDate
        && lhs.transactionIdentifier == rhs.transactionIdentifier
        && lhs.transactionState == rhs.transactionState
    }
  }

  public struct Payment: Equatable {
    public var applicationUsername: String?
    public var productIdentifier: String
    public var quantity: Int
    public var requestData: Data?
    public var simulatesAskToBuyInSandbox: Bool

    public init(
      applicationUsername: String?,
      productIdentifier: String,
      quantity: Int,
      requestData: Data?,
      simulatesAskToBuyInSandbox: Bool
    ) {
      self.applicationUsername = applicationUsername
      self.productIdentifier = productIdentifier
      self.quantity = quantity
      self.requestData = requestData
      self.simulatesAskToBuyInSandbox = simulatesAskToBuyInSandbox
    }
  }
}

extension SKPaymentTransactionState {
  public var canBeVerified: Bool {
    switch self {
    case .purchasing, .failed, .deferred:
      return false
    case .purchased, .restored:
      return true
    @unknown default:
      return false
    }
  }
}

extension StoreKitClient.PaymentTransaction {
  init(rawValue: SKPaymentTransaction) {
    self.error = rawValue.error as NSError?
    self._original = { rawValue.original.map(Self.init(rawValue:)) }
    self.payment = .init(rawValue: rawValue.payment)
    self.rawValue = rawValue
    self.transactionDate = rawValue.transactionDate
    self.transactionIdentifier = rawValue.transactionIdentifier
    self.transactionState = rawValue.transactionState
  }
}

extension StoreKitClient.Payment {
  init(rawValue: SKPayment) {
    self.applicationUsername = rawValue.applicationUsername
    self.productIdentifier = rawValue.productIdentifier
    self.quantity = rawValue.quantity
    self.requestData = rawValue.requestData
    self.simulatesAskToBuyInSandbox = rawValue.simulatesAskToBuyInSandbox
  }
}

extension StoreKitClient.Product {
  init(rawValue: SKProduct) {
    self.downloadContentLengths = rawValue.downloadContentLengths
    self.downloadContentVersion = rawValue.downloadContentVersion
    self.isDownloadable = rawValue.isDownloadable
    self.localizedDescription = rawValue.localizedDescription
    self.localizedTitle = rawValue.localizedTitle
    self.price = rawValue.price
    self.priceLocale = rawValue.priceLocale
    self.productIdentifier = rawValue.productIdentifier
  }
}
