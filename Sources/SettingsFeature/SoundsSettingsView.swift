import ComposableArchitecture
import Styleguide
import SwiftUI

struct SoundsSettingsView: View {
  let store: Store<SettingsState, SettingsAction>
  @ObservedObject var viewStore: ViewStore<SettingsState, SettingsAction>

  init(store: Store<SettingsState, SettingsAction>) {
    self.store = store
    self.viewStore = ViewStore(self.store)
  }

  var body: some View {
    SettingsForm {
      SettingsRow {
        VStack(alignment: .leading, spacing: 24) {
          Text("Music volume")

          VStack {
            Slider(
              value: self.viewStore.binding(\.$userSettings.musicVolume).animation(), in: 0...1
            )
            .accentColor(.isowordsOrange)

            if self.viewStore.userSettings.musicVolume <= 0 {
              Text("Music is off")
                .foregroundColor(.gray)
                .adaptiveFont(.matterMedium, size: 14)
                .transition(.opacity)
            }
          }
        }
      }

      SettingsRow {
        VStack(alignment: .leading, spacing: 24) {
          Text("Sound FX volume")

          VStack {
            Slider(
              value: self.viewStore.binding(\.$userSettings.soundEffectsVolume).animation(),
              in: 0...1
            )
            .accentColor(.isowordsOrange)

            if self.viewStore.userSettings.soundEffectsVolume <= 0 {
              Text("Sound FX are off")
                .foregroundColor(.gray)
                .adaptiveFont(.matterMedium, size: 14)
                .transition(.opacity)
            }
          }
        }
      }
    }
    .navigationStyle(title: Text("Sounds"))
  }
}

#if DEBUG
  import SwiftUIHelpers

  struct SoundsSettingsView_Previews: PreviewProvider {
    static var previews: some View {
      Preview {
        NavigationView {
          SoundsSettingsView(
            store: .init(
              initialState: .init(userSettings: .init(musicVolume: 0.5, soundEffectsVolume: 0.5)),
              reducer: settingsReducer,
              environment: .noop
            )
          )
        }
      }
    }
  }
#endif
