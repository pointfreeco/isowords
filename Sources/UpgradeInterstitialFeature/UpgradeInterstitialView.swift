import Combine
import CombineHelpers
import ComposableArchitecture
import ComposableStoreKit
import ServerConfig
import ServerConfigClient
import StoreKit
import Styleguide
import SwiftUI
import SwiftUIHelpers

public enum GameContext: String, Codable {
  case dailyChallenge
  case shared
  case solo
  case turnBased
}

public struct UpgradeInterstitialState: Equatable {
  public var isDismissable: Bool
  public var isPurchasing: Bool
  public var products: [StoreKitClient.Product]?
  public var secondsPassedCount: Int
  public var upgradeInterstitialDuration: Int

  public init(
    isDismissable: Bool = false,
    isPurchasing: Bool = false,
    products: [StoreKitClient.Product]? = nil,
    secondsPassedCount: Int = 0,
    upgradeInterstitialDuration: Int = ServerConfig.UpgradeInterstitial.default.duration
  ) {
    self.isDismissable = isDismissable
    self.isPurchasing = isPurchasing
    self.products = products
    self.secondsPassedCount = secondsPassedCount
    self.upgradeInterstitialDuration = upgradeInterstitialDuration
  }
}

public enum UpgradeInterstitialAction: Equatable {
  case delegate(DelegateAction)
  case maybeLaterButtonTapped
  case onAppear
  case paymentTransaction(StoreKitClient.PaymentTransactionObserverEvent)
  case timerTick
  case upgradeButtonTapped

  public enum DelegateAction {
    case close
    case fullGamePurchased
  }
}

public struct UpgradeInterstitialEnvironment {
  public var mainRunLoop: AnySchedulerOf<RunLoop>
  public var serverConfig: ServerConfigClient
  public var storeKit: StoreKitClient

  public init(
    mainRunLoop: AnySchedulerOf<RunLoop>,
    serverConfig: ServerConfigClient,
    storeKit: StoreKitClient
  ) {
    self.mainRunLoop = mainRunLoop
    self.serverConfig = serverConfig
    self.storeKit = storeKit
  }
}

public let upgradeInterstitialReducer = Reducer<
  UpgradeInterstitialState, UpgradeInterstitialAction, UpgradeInterstitialEnvironment
> { state, action, environment in

  struct StoreKitObserverId: Hashable {}
  struct TimerId: Hashable {}

  switch action {
  case .delegate:
    return .none

  case .maybeLaterButtonTapped:
    return .merge(
      .cancel(id: StoreKitObserverId()),
      .cancel(id: TimerId()),
      Effect(value: .delegate(.close))
        .receive(on: ImmediateScheduler.shared.animation())
        .eraseToEffect()
    )

  case let .paymentTransaction(event):
    switch event {
    case .removedTransactions:
      state.isPurchasing = false
    case .restoreCompletedTransactionsFailed:
      break
    case .restoreCompletedTransactionsFinished:
      state.isPurchasing = false
    case .updatedTransactions:
      break
    }

    return event.isFullGamePurchased(
      identifier: environment.serverConfig.config().productIdentifiers.fullGame
    )
      ? .merge(
        .cancel(id: StoreKitObserverId()),
        .cancel(id: TimerId()),
        Effect(value: .delegate(.fullGamePurchased))
      )
      : .none

  case .onAppear:
    state.upgradeInterstitialDuration =
      environment.serverConfig.config().upgradeInterstitial.duration

    return .merge(
      environment.storeKit.observer
        .receive(on: environment.mainRunLoop.animation())
        .map(UpgradeInterstitialAction.paymentTransaction)
        .eraseToEffect()
        .cancellable(id: StoreKitObserverId()),

      !state.isDismissable
        ? Effect.timer(id: TimerId(), every: 1, on: environment.mainRunLoop.animation())
          .map { _ in UpgradeInterstitialAction.timerTick }
          .eraseToEffect()
          .cancellable(id: TimerId())
        : .none
    )

  case .timerTick:
    state.secondsPassedCount += 1
    return state.secondsPassedCount == state.upgradeInterstitialDuration
      ? .cancel(id: TimerId())
      : .none

  case .upgradeButtonTapped:
    state.isPurchasing = true

    let payment = SKMutablePayment()
    payment.productIdentifier = environment.serverConfig.config().productIdentifiers.fullGame
    payment.quantity = 1
    return environment.storeKit.addPayment(payment)
      .fireAndForget()
  }
}

public struct UpgradeInterstitialView: View {
  @Environment(\.colorScheme) var colorScheme
  let store: Store<UpgradeInterstitialState, UpgradeInterstitialAction>

  public init(store: Store<UpgradeInterstitialState, UpgradeInterstitialAction>) {
    self.store = store
  }

  public var body: some View {
    WithViewStore(self.store) { viewStore in
      VStack {
        VStack {
          if !viewStore.isDismissable
            && viewStore.secondsPassedCount < viewStore.upgradeInterstitialDuration
          {
            Text("\(viewStore.upgradeInterstitialDuration - viewStore.secondsPassedCount)s")
              .animation(nil)
              .multilineTextAlignment(.center)
              .adaptiveFont(.matterMedium, size: 16) { $0.monospacedDigit() }
              .adaptivePadding(.bottom)
              .transition(.opacity)
          }

          VStack(spacing: 32) {
            (Text("A personal\nappeal from\nthe creators\nof ")
              + Text("isowords").fontWeight(.medium))
              .multilineTextAlignment(.center)
              .adaptiveFont(.matter, size: 35)
              .fixedSize()

            Text(
              """
              Hello! We could put an ad here, but we chose not to because ads suck. But also, keeping \
              this game running costs money. So if you can, please purchase the full version and help \
              support the development of new features!
              """
            )
            .multilineTextAlignment(.center)
            .adaptiveFont(.matter, size: 16)
          }
          .adaptivePadding()

          Spacer()
        }
        .applying {
          if self.colorScheme == .dark {
            $0.foreground(
              LinearGradient(
                gradient: Gradient(colors: [.hex(0xF3EBA4), .hex(0xE1665B)]),
                startPoint: .top,
                endPoint: .bottom
              )
            )
          } else {
            $0
          }
        }

        VStack(spacing: 24) {
          Button(action: { viewStore.send(.upgradeButtonTapped, animation: .default) }) {
            HStack(spacing: .grid(2)) {
              if viewStore.isPurchasing {
                ProgressView()
                  .progressViewStyle(
                    CircularProgressViewStyle(
                      tint: self.colorScheme == .dark ? .isowordsBlack : .hex(0xE1665B)
                    )
                  )
              }
              Text("Upgrade")
            }
            .frame(maxWidth: .infinity)
          }
          .buttonStyle(
            ActionButtonStyle(
              backgroundColor: self.colorScheme == .dark ? .hex(0xE1665B) : .isowordsBlack,
              foregroundColor: self.colorScheme == .dark ? .isowordsBlack : .hex(0xE1665B)
            )
          )
          .disabled(viewStore.isPurchasing)

          if viewStore.isDismissable
            || viewStore.secondsPassedCount >= viewStore.upgradeInterstitialDuration
          {
            Button(action: { viewStore.send(.maybeLaterButtonTapped, animation: .default) }) {
              Text("Maybe later")
                .foregroundColor(self.colorScheme == .dark ? .hex(0xE1665B) : .isowordsBlack)
            }
            .foregroundColor(.isowordsBlack)
            .adaptiveFont(.matterMedium, size: 14)
            .transition(.opacity)
          }
        }
      }
      .adaptivePadding()
      .onAppear { viewStore.send(.onAppear) }
      .applying {
        if self.colorScheme == .dark {
          $0.background(
            Color.isowordsBlack
              .ignoresSafeArea()
          )
        } else {
          $0.background(
            LinearGradient(
              gradient: Gradient(colors: [.hex(0xF3EBA4), .hex(0xE1665B)]),
              startPoint: .top,
              endPoint: .bottom
            )
            .ignoresSafeArea()
          )
        }
      }
    }
  }
}

extension StoreKitClient.PaymentTransactionObserverEvent {
  fileprivate func isFullGamePurchased(identifier: String) -> Bool {
    switch self {
    case let .updatedTransactions(transactions):
      return transactions.contains { transaction in
        transaction.transactionState == .purchased
          && transaction.payment.productIdentifier == identifier
      }

    default:
      return false
    }
  }
}

extension Effect where Output == Bool, Failure == Error {
  public static func showUpgradeInterstitial(
    gameContext: GameContext,
    isFullGamePurchased: Bool,
    serverConfig: ServerConfig,
    playedGamesCount: () -> Effect<Int, Error>
  ) -> Self {
    playedGamesCount()
      .map { count in
        !isFullGamePurchased
          && shouldShowInterstitial(
            gamePlayedCount: count,
            gameContext: gameContext,
            serverConfig: serverConfig
          )
      }
      .eraseToEffect()
  }
}

func shouldShowInterstitial(
  gamePlayedCount: Int,
  gameContext: GameContext,
  serverConfig: ServerConfig
) -> Bool {
  let triggerCount = serverConfig.triggerCount(gameContext: gameContext)
  let triggerEvery = serverConfig.triggerEvery(gameContext: gameContext)
  return gamePlayedCount >= triggerCount
    && (gamePlayedCount - triggerCount) % triggerEvery == 0
}

extension ServerConfig {
  fileprivate func triggerCount(gameContext: GameContext) -> Int {
    switch gameContext {
    case .dailyChallenge:
      return self.upgradeInterstitial.playedDailyChallengeGamesTriggerCount
    case .shared:
      return 0  // TODO: update this once we actually support shared games
    case .solo:
      return self.upgradeInterstitial.playedSoloGamesTriggerCount
    case .turnBased:
      return self.upgradeInterstitial.playedMultiplayerGamesTriggerCount
    }
  }

  fileprivate func triggerEvery(gameContext: GameContext) -> Int {
    switch gameContext {
    case .dailyChallenge:
      return self.upgradeInterstitial.dailyChallengeTriggerEvery
    case .shared:
      return 1
    case .solo:
      return self.upgradeInterstitial.soloGameTriggerEvery
    case .turnBased:
      return self.upgradeInterstitial.multiplayerGameTriggerEvery
    }
  }
}

extension View {
  func foreground<V: View>(_ view: V) -> some View {
    self.overlay(view).mask(self)
  }
}

struct UpgradeInterstitialPreviews: PreviewProvider {
  static var previews: some View {
    Preview {
      NavigationView {
        UpgradeInterstitialView(
          store: .init(
            initialState: .init(isDismissable: true, secondsPassedCount: 0),
            reducer: upgradeInterstitialReducer,
            environment: .init(
              mainRunLoop: RunLoop.main.eraseToAnyScheduler(),
              serverConfig: .noop,
              storeKit: .live()
            )
          )
        )
        .navigationBarHidden(true)
      }
    }
  }
}
