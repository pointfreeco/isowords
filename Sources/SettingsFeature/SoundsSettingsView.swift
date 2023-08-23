import ComposableArchitecture
import Styleguide
import SwiftUI

struct SoundsSettingsView: View {
  let store: StoreOf<Settings>
  @ObservedObject var viewStore: ViewStoreOf<Settings>

  init(store: StoreOf<Settings>) {
    self.store = store
    self.viewStore = ViewStore(self.store, observe: { $0 })
  }

  var body: some View {
    SettingsForm {
      SettingsRow {
        VStack(alignment: .leading, spacing: 24) {
          Text("Music volume")

          VStack {
            Slider(
              value: self.viewStore.$userSettings.musicVolume.animation(), in: 0...1
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
              value: self.viewStore.$userSettings.soundEffectsVolume.animation(),
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
  import UserSettingsClient

  struct SoundsSettingsView_Previews: PreviewProvider {
    static var previews: some View {
      Preview {
        NavigationView {
          SoundsSettingsView(
            store: Store(initialState: Settings.State()) {
              Settings()
            } withDependencies: {
              $0.userSettings = .mock(
                initialUserSettings: UserSettings(
                  musicVolume: 0.5,
                  soundEffectsVolume: 0.5
                )
              )
            }
          )
        }
      }
    }
  }
#endif
