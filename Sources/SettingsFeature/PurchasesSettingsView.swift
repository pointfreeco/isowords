import ComposableArchitecture
import Styleguide
import SwiftUI

struct PurchasesSettingsView: View {
  let store: StoreOf<Settings>

  var body: some View {
    SettingsForm {
      if let fullGamePurchasedAt = self.store.fullGamePurchasedAt {
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
        if !self.store.isPurchasing,
          let fullGameProduct = self.store.fullGameProduct
        {
          switch fullGameProduct {
          case let .success(product):
            SettingsRow {
              Button {
                self.store.send(.tappedProduct(product), animation: .default)
              } label: {
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
            Button {
            } label: {
              ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .isowordsOrange))
            }
          }
        }

        if !self.store.isRestoring {
          SettingsRow {
            Button {
              self.store.send(.restoreButtonTapped, animation: .default)
            } label: {
              Text("Restore purchases")
                .foregroundColor(.isowordsOrange)
                .adaptiveFont(.matterMedium, size: 20)
            }
          }
        } else {
          SettingsRow {
            Button {
            } label: {
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
            store: Store(initialState: Settings.State(fullGamePurchasedAt: Date())) {
              Settings()
            }
          )
        }

        NavigationView {
          PurchasesSettingsView(
            store: Store(initialState: Settings.State()) {
              Settings()
            }
          )
        }
      }
    }
  }
#endif
