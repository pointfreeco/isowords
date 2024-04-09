import ComposableArchitecture
import Styleguide
import SwiftUI

struct NotificationsSettingsView: View {
  @Bindable var store: StoreOf<Settings>

  var body: some View {
    SettingsForm {
      SettingsRow {
        Toggle(
          "Enable notifications", isOn: $store.userSettings.enableNotifications.animation()
        )
        .adaptiveFont(.matterMedium, size: 16)
      }

      if store.userSettings.enableNotifications {
        SettingsRow {
          VStack(alignment: .leading, spacing: 16) {
            Toggle(
              "Daily challenge reminders", isOn: $store.userSettings.sendDailyChallengeReminder
            )
            .adaptiveFont(.matterMedium, size: 16)

            Text("Get notified when a new challenge is available.")
              .foregroundColor(.gray)
              .adaptiveFont(.matterMedium, size: 12)
          }
        }

        SettingsRow {
          VStack(alignment: .leading, spacing: 16) {
            Toggle("Daily challenge summary", isOn: $store.userSettings.sendDailyChallengeSummary)
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
