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

  public init(
    store: StoreOf<Settings>,
    navPresentationStyle: NavPresentationStyle
  ) {
    self.navPresentationStyle = navPresentationStyle
    self.store = store
  }

  public var body: some View {
    SettingsForm {
      SettingsSection(title: "Support the game", padContents: false) {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 16) {
            if !self.store.isFullGamePurchased {
              Group {
                if !self.store.isPurchasing,
                  let fullGameProduct = self.store.fullGameProduct
                {
                  switch fullGameProduct {
                  case let .success(product):
                    Button {
                      self.store.send(.tappedProduct(product), animation: .default)
                    } label: {
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
                  Button {
                  } label: {
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

            Button {
              self.store.send(.leaveUsAReviewButtonTapped)
            } label: {
              Image(systemName: "star")
                .font(.system(size: 40))
            }
            .buttonStyle(
              SupportButtonStyle(
                title: "Leave us a review",
                backgroundColor: .hex(0xE89D79)
              )
            )

            Button {
              self.isSharePresented.toggle()
            } label: {
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
        destination: StatsView(store: self.store.scope(state: \.stats, action: \.stats)),
        title: "Stats"
      )
      SettingsNavigationLink(
        destination: PurchasesSettingsView(store: self.store),
        title: "Purchases"
      )
      if self.store.isFullGamePurchased {
        SettingsRow {
          Button {
            self.store.send(.leaveUsAReviewButtonTapped)
          } label: {
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
        if let buildNumber = self.store.buildNumber {
          Text("Build \(buildNumber.rawValue)")
        }
        Button {
          self.store.send(.reportABugButtonTapped)
        } label: {
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
      onDismiss: { self.store.send(.onDismiss) }
    )
    .task { await self.store.send(.task).finish() }
    .alert(store: self.store.scope(state: \.$alert, action: \.alert))
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
        .padding(.horizontal, 16)
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .stroke(Color.adaptiveWhite, lineWidth: 3)
        )

      Text(self.title)
    }
    .foregroundColor(.adaptiveWhite)
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
        NavigationView {
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
              )
            ) {
              Settings()
            } withDependencies: {
              $0.apiClient.currentPlayer = { .init(appleReceipt: .mock, player: .blob) }
            },
            navPresentationStyle: .navigation
          )
        }
      }
    }
  }
#endif
