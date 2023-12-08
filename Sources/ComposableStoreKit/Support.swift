import StoreKit

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
