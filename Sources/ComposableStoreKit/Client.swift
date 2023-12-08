import CasePaths
import DependenciesMacros
import StoreKit

@DependencyClient
public struct StoreKitClient {
  public var addPayment: @Sendable (SKPayment) async -> Void
  public var appStoreReceiptURL: @Sendable () -> URL?
  public var isAuthorizedForPayments: @Sendable () -> Bool = { false }
  public var fetchProducts: @Sendable (Set<String>) async throws -> ProductsResponse
  public var finishTransaction: @Sendable (PaymentTransaction) async -> Void
  public var observer: @Sendable () -> AsyncStream<PaymentTransactionObserverEvent> = { .finished }
  public var requestReview: @Sendable () async -> Void
  public var restoreCompletedTransactions: @Sendable () async -> Void

  @CasePathable
  public enum PaymentTransactionObserverEvent {
    case removedTransactions([PaymentTransaction])
    case restoreCompletedTransactionsFailed(Error)
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
