import ComposableArchitecture
import Styleguide
import SwiftUI

struct AccessibilitySettingsView: View {
  let store: StoreOf<Settings>
  @ObservedObject var viewStore: ViewStoreOf<Settings>

  init(store: StoreOf<Settings>) {
    self.store = store
    self.viewStore = ViewStore(self.store, observe: { $0 })
  }

  var body: some View {
    SettingsForm {
      SettingsRow {
        VStack(alignment: .leading) {
          Toggle("Cube motion", isOn: self.viewStore.$userSettings.enableGyroMotion)
            .adaptiveFont(.matterMedium, size: 16)

          Text("Use your device’s gyroscope to apply a small amount of motion to the cube.")
            .foregroundColor(.gray)
            .adaptiveFont(.matterMedium, size: 12)
            .transition(.opacity)
        }
      }
      SettingsRow {
        VStack(alignment: .leading) {
          Toggle("Haptics", isOn: self.viewStore.$userSettings.enableHaptics)
            .adaptiveFont(.matterMedium, size: 16)
        }
      }
      SettingsRow {
        VStack(alignment: .leading) {
          Toggle(
            "Reduce animation",
            isOn: self.viewStore.$userSettings.enableReducedAnimation
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
              initialState: Settings.State()
            ) {
              
            }
          )
        }
      }
    }
  }
#endif
