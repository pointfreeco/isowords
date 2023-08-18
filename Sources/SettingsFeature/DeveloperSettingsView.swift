import ComposableArchitecture
import Styleguide
import SwiftUI

struct DeveloperSettingsView: View {
  let store: StoreOf<Settings>
  @ObservedObject var viewStore: ViewStoreOf<Settings>
  @AppStorage(.enableCubeShadow) var enableCubeShadow
  @AppStorage(.showSceneStatistics) var showSceneStatistics

  init(store: StoreOf<Settings>) {
    self.store = store
    self.viewStore = ViewStore(store, observe: { $0 })
  }

  var body: some View {
    SettingsForm {
      SettingsRow {

        VStack(alignment: .leading) {
          Text("API")
          Text(self.viewStore.developer.currentBaseUrl.rawValue)
            .adaptiveFont(.matter, size: 14)

          Picker("Base URL", selection: self.viewStore.$developer.currentBaseUrl) {
            ForEach(DeveloperSettings.BaseUrl.allCases, id: \.self) {
              Text($0.description)
            }
          }
          .pickerStyle(InlinePickerStyle())
          .frame(height: 130)
        }
      }

      SettingsRow {
        Toggle("Shadows", isOn: self.$enableCubeShadow)
      }

      SettingsRow {
        Toggle("Scene statistics", isOn: self.$showSceneStatistics)
      }
    }
    .navigationStyle(title: Text("Developer"))
  }
}

#if DEBUG
  import Overture

  struct DeveloperSettingsView_Previews: PreviewProvider {
    static var previews: some View {
      DeveloperSettingsView(
        store: Store(
          initialState: Settings.State()
        ) {

        }
      )
    }
  }
#endif
