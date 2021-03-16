import SwiftUI
import SwiftUIHelpers

public struct ActionButtonStyle: ButtonStyle {
  let backgroundColor: Color
  let foregroundColor: Color
  let isActive: Bool

  public init(
    backgroundColor: Color = .adaptiveBlack,
    foregroundColor: Color = .adaptiveWhite,
    isActive: Bool = true
  ) {
    self.backgroundColor = backgroundColor
    self.foregroundColor = foregroundColor
    self.isActive = isActive
  }

  public func makeBody(configuration: Self.Configuration) -> some View {
    return configuration.label
      .foregroundColor(
        self.foregroundColor
          .opacity(!configuration.isPressed ? 1 : 0.5)
      )
      .padding([.leading, .trailing], .grid(5))
      .padding([.top, .bottom], .grid(6))
      .background(
        RoundedRectangle(cornerRadius: 13)
          .fill(
            self.backgroundColor
              .opacity(self.isActive && !configuration.isPressed ? 1 : 0.5)
          )
      )
      .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
      .adaptiveFont(.matterMedium, size: 16)
  }
}

struct Buttons_Previews: PreviewProvider {
  static var previews: some View {
    let view = NavigationView {
      VStack {
        Section(header: Text("Active")) {
          Button("Button") {}
          NavigationLink("Navigation link", destination: EmptyView())
        }
        .buttonStyle(ActionButtonStyle())

        Section(header: Text("In-active")) {
          Button("Button") {}
          NavigationLink("Navigation link", destination: EmptyView())
        }
        .buttonStyle(ActionButtonStyle(isActive: false))
      }
    }

    return Group {
      view
        .environment(\.colorScheme, .light)
      view
        .environment(\.colorScheme, .dark)
    }
  }
}
