import Build
import ComposableArchitecture
import ComposableStoreKit
import ServerConfigClient
import StatsFeature
import Styleguide
import SwiftUI
import SwiftUIHelpers

public struct SettingsView: View {
  @Environment(\.colorScheme) var colorScheme
  let navPresentationStyle: NavPresentationStyle
  @State var isSharePresented = false
  let store: StoreOf<Settings>
  @ObservedObject var viewStore: ViewStore<ViewState, Settings.Action>

  struct ViewState: Equatable {
    let buildNumber: Build.Number?
    let fullGameProduct: Result<StoreKitClient.Product, Settings.State.ProductError>?
    let isFullGamePurchased: Bool
    let isPurchasing: Bool

    init(state: Settings.State) {
      self.buildNumber = state.buildNumber
      self.fullGameProduct = state.fullGameProduct
      self.isFullGamePurchased = state.isFullGamePurchased
      self.isPurchasing = state.isPurchasing
    }
  }

  public init(
    store: StoreOf<Settings>,
    navPresentationStyle: NavPresentationStyle
  ) {
    self.navPresentationStyle = navPresentationStyle
    self.store = store
    self.viewStore = ViewStore(self.store.scope(state: ViewState.init))
  }

  public var body: some View {
    SettingsForm {
      SettingsSection(title: "Support the game", padContents: false) {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 16) {
            if !self.viewStore.isFullGamePurchased {
              Group {
                if !self.viewStore.isPurchasing,
                  let fullGameProduct = self.viewStore.fullGameProduct
                {
                  switch fullGameProduct {
                  case let .success(product):
                    Button(
                      action: { self.viewStore.send(.tappedProduct(product), animation: .default) }
                    ) {
                      HStack(alignment: .top, spacing: 0) {
                        Text(product.priceLocale.currencySymbol ?? "$")
                          .adaptiveFont(.matter, size: 24)
                          .padding(.top, 4)
                        Text("\(product.price.doubleValue, specifier: "%.2f")")
                          .adaptiveFont(.matter, size: 50)
                      }
                    }
                  case .failure:
                    EmptyView()
                  }
                } else {
                  Button(action: {}) {
                    ProgressView()
                      .progressViewStyle(CircularProgressViewStyle(tint: .adaptiveWhite))
                      .scaleEffect(1.5, anchor: .center)
                  }
                }
              }
              .buttonStyle(
                SupportButtonStyle(
                  title: "Upgrade now",
                  backgroundColor: .hex(0xEEC38E)
                )
              )
            }

            Button(action: { self.viewStore.send(.leaveUsAReviewButtonTapped) }) {
              Image(systemName: "star")
                .font(.system(size: 40))
            }
            .buttonStyle(
              SupportButtonStyle(
                title: "Leave us a review",
                backgroundColor: .hex(0xE89D79)
              )
            )

            Button(action: { self.isSharePresented.toggle() }) {
              Image(systemName: "person.2.fill")
                .font(.system(size: 40))
            }
            .buttonStyle(
              SupportButtonStyle(
                title: "Share with a friend!",
                backgroundColor: .isowordsRed
              )
            )

            // NB: gives a little bit of space at the end of the scroll view
            Divider()
              .hidden()
          }
          .screenEdgePadding(.leading)
        }
      }

      SettingsNavigationLink(
        destination: NotificationsSettingsView(store: self.store),
        title: "Notifications"
      )
      SettingsNavigationLink(
        destination: SoundsSettingsView(store: self.store),
        title: "Sounds"
      )
      SettingsNavigationLink(
        destination: AppearanceSettingsView(store: self.store),
        title: "Appearance"
      )
      SettingsNavigationLink(
        destination: AccessibilitySettingsView(store: self.store),
        title: "Accessibility"
      )
      SettingsNavigationLink(
        destination: StatsView(
          store: self.store.scope(state: \.stats, action: Settings.Action.stats)
        ),
        title: "Stats"
      )
      SettingsNavigationLink(
        destination: PurchasesSettingsView(store: self.store),
        title: "Purchases"
      )
      if self.viewStore.isFullGamePurchased {
        SettingsRow {
          Button(action: { self.viewStore.send(.leaveUsAReviewButtonTapped) }) {
            HStack {
              Text("Leave us a review")
              Spacer()
              Image(systemName: "arrow.up.right.square")
            }
          }
          .buttonStyle(PlainButtonStyle())
        }
      }
      #if DEBUG
        SettingsNavigationLink(
          destination: DeveloperSettingsView(store: self.store),
          title: "\(Image(systemName: "hammer.fill")) Developer"
        )
      #endif

      VStack(spacing: 6) {
        if let buildNumber = self.viewStore.buildNumber {
          Text("Build \(buildNumber.rawValue)")
        }
        Button(action: { self.viewStore.send(.reportABugButtonTapped) }) {
          Text("Report a bug")
            .underline()
        }
      }
      .frame(maxWidth: .infinity)
      .padding(48)
      .adaptiveFont(.matterMedium, size: 12)
    }
    .navigationStyle(
      backgroundColor: .adaptiveWhite,
      foregroundColor: .hex(self.colorScheme == .dark ? 0x7d7d7d : 0x393939),
      title: Text("Settings"),
      navPresentationStyle: self.navPresentationStyle,
      onDismiss: { self.viewStore.send(.onDismiss) }
    )
    .task { await self.viewStore.send(.task).finish() }
    .alert(self.store.scope(state: \.alert), dismiss: .set(\.$alert, nil))
    .sheet(isPresented: self.$isSharePresented) {
      ActivityView(activityItems: [URL(string: "https://www.isowords.xyz")!])
        .ignoresSafeArea()
    }
  }
}

struct SettingsNavigationLink<Destination>: View where Destination: View {
  let destination: Destination
  let title: LocalizedStringKey

  var body: some View {
    SettingsRow {
      NavigationLink(
        destination: self.destination,
        label: {
          HStack {
            Text(self.title)
            Spacer()
            Image(systemName: "arrow.right")
              .font(.system(size: 20))
          }
        }
      )
    }
  }
}

public struct SupportButtonStyle: ButtonStyle {
  let backgroundColor: Color
  let title: String

  init(
    title: String,
    backgroundColor: Color
  ) {
    self.title = title
    self.backgroundColor = backgroundColor
  }

  public func makeBody(configuration: Self.Configuration) -> some View {
    VStack(spacing: 12) {
      configuration.label
        .frame(minWidth: 100 - 16 * 2, minHeight: 100)
        .padding([.leading, .trailing], 16)
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .stroke(Color.adaptiveWhite, lineWidth: 3)
        )

      Text(self.title)
    }
    .foregroundColor(Color.adaptiveWhite)
    .frame(width: 240, height: 210, alignment: .center)
    .background(self.backgroundColor)
    .cornerRadius(12)
    .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
  }
}

#if DEBUG
  import Overture

  struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
      Preview {
        NavigationStack {
          SettingsView(
            store: Store(
              initialState: Settings.State(
                fullGameProduct: .success(
                  StoreKitClient.Product(
                    downloadContentLengths: [],
                    downloadContentVersion: "",
                    isDownloadable: false,
                    localizedDescription: "",
                    localizedTitle: "",
                    price: 4.99,
                    priceLocale: Locale.init(identifier: "en_GB"),
                    productIdentifier: ""
                  )
                )
              ),
              reducer: Settings()
                .dependency(\.apiClient.currentPlayer) {
                  .init(appleReceipt: .mock, player: .blob)
                }
            ),
            navPresentationStyle: .navigation
          )
        }
      }
    }
  }
#endif
