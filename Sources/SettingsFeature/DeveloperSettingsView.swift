import ComposableArchitecture
import Styleguide
import SwiftUI

struct DeveloperSettingsView: View {
  let store: Store<SettingsState, SettingsAction>
  @ObservedObject var viewStore: ViewStore<SettingsState, SettingsAction>

  init(store: Store<SettingsState, SettingsAction>) {
    self.store = store
    self.viewStore = ViewStore(store)
  }

  var body: some View {
    SettingsForm {
      SettingsRow {

        VStack(alignment: .leading) {
          Text("API")
          Text(self.viewStore.developer.currentBaseUrl.rawValue)
            .adaptiveFont(.matter, size: 14)

          Picker(
            "",
            selection: self.viewStore.binding(
              keyPath: \.developer.currentBaseUrl,
              send: SettingsAction.binding
            )
          ) {
            ForEach(DeveloperSettings.BaseUrl.allCases, id: \.self) {
              Text($0.description)
            }
          }
          .frame(height: 130)
        }
      }

      SettingsRow {
        Toggle(
          "Shadows",
          isOn: self.viewStore.binding(
            keyPath: \.enableCubeShadow,
            send: SettingsAction.binding
          )
        )
      }

      SettingsRow {
        VStack(alignment: .leading, spacing: 24) {
          Text("Shadow radius")
            .adaptiveFont(.matterMedium, size: 16)

          Slider(
            value: viewStore.binding(
              keyPath: \.cubeShadowRadius,
              send: SettingsAction.binding
            ),
            in: (0 as CGFloat)...200
          )
          .accentColor(.isowordsOrange)
        }
      }

      SettingsRow {
        Toggle(
          "Scene statistics",
          isOn: viewStore.binding(
            keyPath: \.showSceneStatistics,
            send: SettingsAction.binding
          )
        )
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
          initialState: SettingsState(),
          reducer: settingsReducer,
          environment: .noop
        )
      )
    }
  }
#endif
