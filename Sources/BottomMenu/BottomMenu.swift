import Styleguide
import SwiftUI

public struct BottomMenu {
  public var buttons: [Button]
  public var footerButton: Button?
  public var message: Text?
  public var title: Text

  public init(
    title: Text,
    message: Text? = nil,
    buttons: [Button],
    footerButton: Button? = nil
  ) {
    self.buttons = buttons
    self.footerButton = footerButton
    self.message = message
    self.title = title
  }

  public struct Button: Identifiable {
    public let action: () -> Void
    public let icon: Image
    public let id: UUID
    public let title: Text

    public init(
      title: Text,
      icon: Image,
      action: @escaping () -> Void = {}
    ) {
      self.action = action
      self.icon = icon
      self.id = UUID()
      self.title = title
    }

    fileprivate init(
      title: Text,
      icon: Image,
      id: UUID,
      action: @escaping () -> Void = {}
    ) {
      self.action = action
      self.icon = icon
      self.id = id
      self.title = title
    }

    fileprivate func additionalAction(_ action: @escaping () -> Void) -> Self {
      .init(title: self.title, icon: self.icon, id: self.id) {
        action()
        self.action()
      }
    }
  }
}

extension View {
  public func bottomMenu(
    item: Binding<BottomMenu?>
  ) -> some View {
    BottomMenuWrapper(content: self, item: item)
  }
}

private struct BottomMenuWrapper<Content: View>: View {
  @Environment(\.colorScheme) var colorScheme
  @Environment(\.deviceState) var deviceState
  let content: Content
  @Binding var item: BottomMenu?

  var body: some View {
    self.content
      .overlay {
        if self.item != nil {
          Rectangle()
            .fill(Color.isowordsBlack.opacity(0.4))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onTapGesture { self.item = nil }
            .zIndex(1)
            .transition(.opacity.animation(.default))
            .ignoresSafeArea()
        }
      }
      .overlay(alignment: .bottom) {
        if let menu = self.item {
          VStack(spacing: 24) {
            Group {
              HStack {
                menu.title
                  .adaptiveFont(.matterMedium, size: 18)
                Spacer()
                Button(action: { self.item = nil }) {
                  Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                }
              }

              if let message = menu.message {
                message
                  .adaptiveFont(.matterMedium, size: 24)
              }
            }
            .foregroundColor(self.colorScheme == .light ? .white : .isowordsOrange)

            HStack(spacing: 24) {
              ForEach(menu.buttons) { button in
                MenuButton(
                  button:
                    button
                    .additionalAction { self.item = nil }
                )
              }
            }

            if let footerButton = menu.footerButton {
              Button(
                action: {
                  self.item = nil
                  footerButton.action()
                }
              ) {
                HStack {
                  footerButton.title
                    .adaptiveFont(.matterMedium, size: 18)
                  Spacer()
                  footerButton.icon
                }
              }
              .buttonStyle(
                ActionButtonStyle(
                  backgroundColor: self.colorScheme == .dark ? .isowordsOrange : .white,
                  foregroundColor: self.colorScheme == .dark ? .isowordsBlack : .isowordsOrange
                )
              )
            }
          }
          .frame(maxWidth: .infinity)
          .padding(24)
          .padding(.bottom)
          .background {
            Group {
              self.colorScheme == .light ? Color.isowordsOrange : .hex(0x242424)
            }
            .adaptiveCornerRadius([UIRectCorner.topLeft, .topRight], .grid(3))
            .ignoresSafeArea()
          }
          .transition(.move(edge: .bottom).animation(.default))
          .screenEdgePadding(self.deviceState.isPad ? .horizontal : [])
        }
      }
  }
}

private struct MenuButton: View {
  let button: BottomMenu.Button
  @Environment(\.colorScheme) var colorScheme

  var body: some View {
    Button(action: self.button.action) {
      VStack(spacing: 16) {
        self.button.icon
          .colorMultiply(self.colorScheme == .light ? .isowordsOrange : .isowordsBlack)

        self.button.title
          .adaptiveFont(.matterMedium, size: 18)
      }
      .foregroundColor(self.colorScheme == .light ? .isowordsOrange : .isowordsBlack)
      .frame(maxWidth: .infinity)
      .padding([.top, .bottom], 24)
      .background(self.colorScheme == .light ? Color.white : .isowordsOrange)
      .continuousCornerRadius(12)
    }
    .buttonStyle(MenuButtonStyle())
  }
}

public struct MenuButtonStyle: ButtonStyle {
  public func makeBody(configuration: Self.Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
  }
}

#if DEBUG
  import SwiftUIHelpers

  struct BottomMenu_Classic_Previews: PreviewProvider {
    struct TestView: View {
      @State var menu: BottomMenu? = Self.sampleMenu

      var body: some View {
        Button("Present") { withAnimation { self.toggle() } }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .bottomMenu(item: self.$menu.animation())
      }

      func toggle() {
        self.menu = self.menu == nil ? Self.sampleMenu : nil
      }

      static let sampleMenu = BottomMenu(
        title: Text("vs mbrandonw"),
        message: Text("Are you sure you want to remove this cube? This will end your turn."),
        buttons: [],
        footerButton: .init(
          title: Text("Settings"),
          icon: Image(systemName: "gear"),
          action: {}
        )
      )
    }

    static var previews: some View {
      Preview {
        TestView()
      }
    }
  }
#endif
