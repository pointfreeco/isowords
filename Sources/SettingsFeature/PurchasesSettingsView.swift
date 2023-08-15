import ComposableArchitecture
import Styleguide
import SwiftUI

struct PurchasesSettingsView: View {
  let store: StoreOf<Settings>
  @ObservedObject var viewStore: ViewStoreOf<Settings>

  init(store: StoreOf<Settings>) {
    self.store = store
    self.viewStore = ViewStore(store, observe: { $0 })
  }

  var body: some View {
    SettingsForm {
      if let fullGamePurchasedAt = self.viewStore.fullGamePurchasedAt {
        VStack(alignment: .leading, spacing: 16) {
          Text("🎉")
            .font(.system(size: 40))

          Text("Purchased on \(fullGamePurchasedAt, style: .date). Thank you!")
            .adaptiveFont(.matterMedium, size: 20)
            .foregroundColor(.adaptiveWhite)
        }
        .adaptivePadding(.all, 24)
        .frame(maxWidth: .infinity)
        .background(Color.isowordsOrange)
        .continuousCornerRadius(12)
        .padding()
      } else {
        if !self.viewStore.isPurchasing,
          let fullGameProduct = self.viewStore.fullGameProduct
        {
          switch fullGameProduct {
          case let .success(product):
            SettingsRow {
              Button(
                action: { self.viewStore.send(.tappedProduct(product), animation: .default) }
              ) {
                Text("Upgrade")
                  .foregroundColor(.isowordsOrange)
                  .adaptiveFont(.matterMedium, size: 20)
              }
            }
          case .failure:
            EmptyView()
          }
        } else {
          SettingsRow {
            Button(action: {}) {
              ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .isowordsOrange))
            }
          }
        }

        if !self.viewStore.isRestoring {
          SettingsRow {
            Button(action: { self.viewStore.send(.restoreButtonTapped, animation: .default) }) {
              Text("Restore purchases")
                .foregroundColor(.isowordsOrange)
                .adaptiveFont(.matterMedium, size: 20)
            }
          }
        } else {
          SettingsRow {
            Button(action: {}) {
              ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .isowordsOrange))
            }
          }
        }
      }
    }
    .navigationStyle(title: Text("Purchases"))
  }
}

#if DEBUG
  import SwiftUIHelpers

  struct PurchasesSettingsView_Previews: PreviewProvider {
    static var previews: some View {
      Preview {
        NavigationView {
          PurchasesSettingsView(
            store: Store(
              initialState: Settings.State(
                fullGamePurchasedAt: Date()
              )
            ) {
              Settings()
            }
          )
        }

        NavigationView {
          PurchasesSettingsView(
            store: Store(
              initialState: Settings.State()
            ) {
              Settings()
            }
          )
        }
      }
    }
  }
#endif
