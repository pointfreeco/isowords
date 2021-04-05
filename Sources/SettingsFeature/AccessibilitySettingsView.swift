import ComposableArchitecture
import Styleguide
import SwiftUI

struct AccessibilitySettingsView: View {
  let store: Store<SettingsState, SettingsAction>
  @ObservedObject var viewStore: ViewStore<SettingsState, SettingsAction>

  init(store: Store<SettingsState, SettingsAction>) {
    self.store = store
    self.viewStore = ViewStore(self.store)
  }

  var body: some View {
    SettingsForm {
      SettingsRow {
        VStack(alignment: .leading) {
          Toggle(
            "Cube motion",
            isOn: self.viewStore.binding(
              keyPath: \.userSettings.enableGyroMotion,
              send: SettingsAction.binding
            )
          )
          .adaptiveFont(.matterMedium, size: 16)

          Text("Use your device’s gyroscope to apply a small amount of motion to the cube.")
            .foregroundColor(.gray)
            .adaptiveFont(.matterMedium, size: 12)
            .transition(.opacity)
        }
      }
      SettingsRow {
        VStack(alignment: .leading) {
          Toggle(
            "Haptics",
            isOn: self.viewStore.binding(
              keyPath: \.userSettings.enableHaptics,
              send: SettingsAction.binding
            )
          )
          .adaptiveFont(.matterMedium, size: 16)
        }
      }
      SettingsRow {
        VStack(alignment: .leading) {
          Toggle(
            "Reduce animation",
            isOn: self.viewStore.binding(
              keyPath: \.userSettings.enableReducedAnimation,
              send: SettingsAction.binding
            )
          )
          .adaptiveFont(.matterMedium, size: 16)
        }
      }
    }
    .navigationStyle(title: Text("Accessibility"))
  }
}

#if DEBUG
  import SwiftUIHelpers

  struct AccessibilitySettingsView_Previews: PreviewProvider {
    static var previews: some View {
      Preview {
        NavigationView {
          AccessibilitySettingsView(
            store: .init(
              initialState: SettingsState(),
              reducer: .empty,
              environment: ()
            )
          )
        }
      }
    }
  }
#endif
