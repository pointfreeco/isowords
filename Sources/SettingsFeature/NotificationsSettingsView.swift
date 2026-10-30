import ComposableArchitecture
import Styleguide
import SwiftUI

struct NotificationsSettingsView: View {
  let store: StoreOf<Settings>

  var body: some View {
    SettingsForm {
      SettingsRow {
        Toggle(
          "Enable notifications",
          isOn: Binding(
            get: { store.userSettings.enableNotifications },
            set: { isOn in withAnimation { _ = store.send(.enableNotificationsToggled(isOn)) } }
          )
        )
        .adaptiveFont(.matterMedium, size: 16)
      }

      if store.userSettings.enableNotifications {
        SettingsRow {
          VStack(alignment: .leading, spacing: 16) {
            Toggle(
              "Daily challenge reminders",
              isOn: Binding(
                get: { store.userSettings.sendDailyChallengeReminder },
                set: { _ = store.send(.dailyChallengeReminderToggled($0)) }
              )
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
              "Daily challenge summary",
              isOn: Binding(
                get: { store.userSettings.sendDailyChallengeSummary },
                set: { _ = store.send(.dailyChallengeSummaryToggled($0)) }
              )
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
