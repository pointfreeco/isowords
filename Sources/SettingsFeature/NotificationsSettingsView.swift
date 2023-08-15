import ComposableArchitecture
import Styleguide
import SwiftUI

struct NotificationsSettingsView: View {
  let store: StoreOf<Settings>
  @ObservedObject var viewStore: ViewStoreOf<Settings>

  init(store: StoreOf<Settings>) {
    self.store = store
    self.viewStore = ViewStore(self.store, observe: { $0 })
  }

  var body: some View {
    SettingsForm {
      SettingsRow {
        Toggle(
          "Enable notifications", isOn: self.viewStore.$enableNotifications.animation()
        )
        .adaptiveFont(.matterMedium, size: 16)
      }

      if self.viewStore.enableNotifications {
        SettingsRow {
          VStack(alignment: .leading, spacing: 16) {
            Toggle(
              "Daily challenge reminders",
              isOn: self.viewStore.$sendDailyChallengeReminder
            )
            .adaptiveFont(.matterMedium, size: 16)

            Text("Get notified when a new challenge is available.")
              .foregroundColor(.gray)
              .adaptiveFont(.matterMedium, size: 12)
          }
        }

        SettingsRow {
          VStack(alignment: .leading, spacing: 16) {
            Toggle(
              "Daily challenge summary", isOn: self.viewStore.$sendDailyChallengeSummary
            )
            .adaptiveFont(.matterMedium, size: 16)

            Text("Receive your rank for yesterday’s challenge if you played.")
              .foregroundColor(.gray)
              .adaptiveFont(.matterMedium, size: 12)
          }
        }
      }
    }
    .navigationStyle(title: Text("Notifications"))
  }
}

#if DEBUG
  import ComposableUserNotifications

  struct NotificationsSettingsView_Previews: PreviewProvider {
    static var previews: some View {
      NotificationsSettingsView(
        store: .init(
          initialState: Settings.State(
            userNotificationSettings: .init(authorizationStatus: .authorized)
          )
        ) {
          Settings()
        }
      )
    }
  }
#endif
