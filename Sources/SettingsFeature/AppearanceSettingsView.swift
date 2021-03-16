import ComposableArchitecture
import Styleguide
import SwiftUI

struct AppearanceSettingsView: View {
  let store: Store<SettingsState, SettingsAction>
  @ObservedObject var viewStore: ViewStore<SettingsState, SettingsAction>

  init(store: Store<SettingsState, SettingsAction>) {
    self.store = store
    self.viewStore = ViewStore(self.store)
  }

  var body: some View {
    SettingsForm {
      SettingsSection(title: "Theme") {
        ColorSchemePicker(
          colorScheme: self.viewStore.binding(
            keyPath: \.userSettings.colorScheme,
            send: SettingsAction.binding
          )
        )
      }

      SettingsSection(title: "App Icon", padContents: false) {
        AppIconPicker(
          appIcon: self.viewStore.binding(
            keyPath: \.userSettings.appIcon,
            send: SettingsAction.binding
          )
          .animation()
        )
      }
    }
    .navigationStyle(title: Text("Appearance"))
  }
}

struct AppIconPicker: View {
  @Binding var appIcon: AppIcon?

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: .grid(4)) {
          ForEach(Array(AppIcon.allCases.enumerated()), id: \.element) { offset, appIcon in
            Button(
              action: {
                self.appIcon = self.appIcon == appIcon ? nil : appIcon
              }
            ) {
              Image(uiImage: UIImage(named: appIcon.rawValue, in: Bundle.module, with: nil)!)
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .continuousCornerRadius(12)
                .padding(4)
                .applying {
                  if self.appIcon == appIcon {
                    $0.overlay(
                      RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(appIcon.color, lineWidth: 2)
                    )
                  } else {
                    $0
                  }
                }
                .padding(1)
                .id(appIcon)
            }

            if offset == AppIcon.allCases.count - 2 {
              Spacer()
                .frame(width: 1_000)
            }
          }
        }
        .screenEdgePadding([.leading, .trailing])
      }
      .onAppear {
        proxy.scrollTo(self.appIcon, anchor: .center)
      }
    }
  }
}

public enum AppIcon: String, Codable, CaseIterable, Hashable {
  case icon1 = "icon-1"
  case icon2 = "icon-2"
  case icon3 = "icon-3"
  case icon4 = "icon-4"
  case icon5 = "icon-5"
  case icon6 = "icon-6"
  case icon7 = "icon-7"
  case icon8 = "icon-8"
  case iso = "icon-iso"

  var color: Color {
    switch self {
    case .icon1:
      return .isowordsYellow
    case .icon2:
      return .isowordsOrange
    case .icon3:
      return .isowordsRed

    case .icon4, .icon5, .icon6, .icon7, .icon8, .iso:
      return Color(
        UIColor { trait in
          trait.userInterfaceStyle == .light
            ? .black
            : .white
        }
      )
    }
  }
}

struct ColorSchemePicker: View {
  @Environment(\.colorScheme) var envColorScheme
  @Binding var colorScheme: UserSettings.ColorScheme

  var body: some View {
    ZStack {
      HStack {
        if self.colorScheme != .system {
          Spacer()
            .frame(maxWidth: .infinity)
        }
        if self.colorScheme == .light {
          Spacer()
            .frame(maxWidth: .infinity)
        }
        Rectangle()
          .fill(Color.isowordsOrange)
          .continuousCornerRadius(12)
          .frame(maxWidth: .infinity)
          .padding(4)
        if self.colorScheme == .system {
          Spacer()
            .frame(maxWidth: .infinity)
        }
        if self.colorScheme != .light {
          Spacer()
            .frame(maxWidth: .infinity)
        }
      }

      HStack {
        ForEach([UserSettings.ColorScheme.system, .dark, .light], id: \.self) { colorScheme in
          Button(
            action: {
              withAnimation(.easeOut(duration: 0.2)) {
                self.colorScheme = colorScheme
              }
            }
          ) {
            Text(colorScheme.title)
              .foregroundColor(Color.white)
              .colorMultiply(
                self.titleColor(
                  colorScheme: self.envColorScheme,
                  isSelected: self.colorScheme == colorScheme
                )
              )
              .animation(self.colorScheme == colorScheme ? .default : nil)
              .frame(maxWidth: .infinity)
              .adaptiveFont(.matterMedium, size: 14)
          }
          .buttonStyle(PlainButtonStyle())
        }
        .padding()
      }
    }
    .background(
      Rectangle()
        .fill(self.envColorScheme == .light ? Color.hex(0xF5F5F5) : .hex(0x222222))
    )
    .continuousCornerRadius(12)
  }

  func titleColor(colorScheme: ColorScheme, isSelected: Bool) -> Color {
    switch colorScheme {
    case .light:
      return isSelected ? .white : .isowordsBlack
    case .dark:
      return isSelected ? .isowordsBlack : .hex(0x7d7d7d)
    @unknown default:
      return isSelected ? .white : .isowordsBlack
    }
  }
}

extension UserSettings.ColorScheme {
  fileprivate var title: LocalizedStringKey {
    switch self {
    case .dark:
      return "Dark"
    case .light:
      return "Light"
    case .system:
      return "System"
    }
  }
}

#if DEBUG
  import Overture
  import SwiftUIHelpers

  struct AppearanceSettingsView_Previews: PreviewProvider {
    static var previews: some View {
      Preview {
        NavigationView {
          AppearanceSettingsView(
            store: .init(
              initialState: .init(),
              reducer: settingsReducer,
              environment: SettingsEnvironment.noop
            )
          )
        }
      }
    }
  }
#endif
