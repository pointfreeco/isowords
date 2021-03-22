import SwiftUI

public struct GameButton: View {
  let action: () -> Void
  @Environment(\.adaptiveSize) var adaptiveSize
  let color: Color
  @Environment(\.colorScheme) var colorScheme
  let icon: Image
  let inactiveText: Text?
  let isLoading: Bool
  let resumeText: Text?
  let title: Text

  public init(
    title: Text,
    icon: Image,
    color: Color,
    inactiveText: Text?,
    isLoading: Bool,
    resumeText: Text?,
    action: @escaping () -> Void
  ) {
    self.title = title
    self.icon = icon
    self.color = color
    self.inactiveText = inactiveText
    self.isLoading = isLoading
    self.resumeText = resumeText
    self.action = action
  }

  public var body: some View {
    ZStack {
      Button(action: self.action) {
        Group {
          if let resumeText = self.resumeText {
            self.resumeView(context: resumeText)
              .transition(.opacity)
          } else {
            self.standardView
              .transition(.opacity)
          }
        }
        .opacity(self.isLoading ? 0.25 : 1)
        .foregroundColor(
          self.colorScheme == .light
            ? self.color
            : .black
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(
          self.colorScheme == .light
            ? .black
            : self.color
        )
        .continuousCornerRadius(12)
      }
      .opacity(self.inactiveText == nil ? 1 : 0.5)
      .buttonStyle(GameButtonStyle())

      if self.isLoading {
        ProgressView()
          .progressViewStyle(
            CircularProgressViewStyle(
              tint: self.colorScheme == .light
                ? self.color
                : .black
            )
          )
          .scaleEffect(1.5)
      }
    }
  }

  private func resumeView(context: Text) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      self.title
        .opacity(0.6)
        .adaptivePadding([.leading, .trailing], .grid(2))
        .adaptivePadding([.top], .grid(3))
      Rectangle()
        .fill(Color.adaptiveWhite.opacity(0.2))
        .frame(maxWidth: .infinity)
        .frame(height: 1)
      context
        .adaptivePadding([.leading, .trailing], .grid(3))
      Spacer()
      HStack {
        Image(systemName: "arrow.right")
        Text("Resume")
      }
      .adaptivePadding([.top, .bottom], .grid(1))
      .adaptivePadding([.leading, .trailing], .grid(2))
      .background(
        self.colorScheme == .light
          ? self.color
          : .black
      )
      .foregroundColor(
        self.colorScheme == .light
          ? .black
          : self.color
      )
      .continuousCornerRadius(100)
      .adaptivePadding(.all, .grid(3))
    }
    .adaptiveFont(.matterMedium, size: 14)
    .frame(maxWidth: .infinity)
  }

  private var standardView: some View {
    VStack(spacing: .grid(6)) {
      self.icon
        .font(.system(size: self.adaptiveSize.pad(40)))
        .frame(height: 50, alignment: .center)
      Group {
        if let inactiveText = self.inactiveText {
          inactiveText
            .padding([.leading, .trailing], .grid(2))
            .lineLimit(2)
            .minimumScaleFactor(0.5)
        } else {
          self.title
        }
      }
      .multilineTextAlignment(.center)
      .adaptiveFont(.matterMedium, size: 16)
    }
    .adaptivePadding([.top, .bottom], .grid(5))
  }
}

private struct GameButtonStyle: ButtonStyle {
  func makeBody(configuration: Self.Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
  }
}

#if DEBUG
  import SwiftUIHelpers

  struct SwiftUIView_Previews: PreviewProvider {
    static var previews: some View {
      Preview {
        NavigationView {
          VStack {
            LazyVGrid(
              columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible()),
              ]
            ) {
              GameButton(
                title: Text("Timed"),
                icon: Image(systemName: "clock.fill"),
                color: .isowordsOrange,
                inactiveText: nil,
                isLoading: true,
                resumeText: nil,
                action: {}
              )
              GameButton(
                title: Text("Unlimited"),
                icon: Image(systemName: "infinity"),
                color: .isowordsOrange,
                inactiveText: nil,
                isLoading: false,
                resumeText: Text("1,234 points"),
                action: {}
              )
            }
            .padding()

            LazyVGrid(
              columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible()),
              ]
            ) {
              GameButton(
                title: Text("Timed"),
                icon: Image(systemName: "clock.fill"),
                color: .isowordsOrange,
                inactiveText: Text("Played.\n#4 of 1,234"),
                isLoading: false,
                resumeText: nil,
                action: {}
              )
              GameButton(
                title: Text("Unlimited"),
                icon: Image(systemName: "infinity"),
                color: .isowordsOrange,
                inactiveText: nil,
                isLoading: false,
                resumeText: nil,
                action: {}
              )
            }
            .padding()
          }
        }
      }
    }
  }
#endif
