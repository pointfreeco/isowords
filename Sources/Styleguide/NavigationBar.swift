import SwiftUI

public enum NavPresentationStyle {
  case modal
  case navigation
}

extension View {
  public func navigationStyle<Title: View, Trailing: View>(
    backgroundColor: Color = .adaptiveWhite,
    foregroundColor: Color = .adaptiveBlack,
    title: Title,
    navPresentationStyle: NavPresentationStyle = .navigation,
    trailing: Trailing,
    onDismiss: @escaping () -> Void = {}
  ) -> some View {
    NavigationBar(
      backgroundColor: backgroundColor,
      content: self,
      foregroundColor: foregroundColor,
      navPresentationStyle: navPresentationStyle,
      onDismiss: onDismiss,
      title: title,
      trailing: trailing
    )
  }

  public func navigationStyle<Title: View>(
    backgroundColor: Color = .adaptiveWhite,
    foregroundColor: Color = .adaptiveBlack,
    title: Title,
    navPresentationStyle: NavPresentationStyle = .navigation,
    onDismiss: @escaping () -> Void = {}
  ) -> some View {
    self.navigationStyle(
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      title: title,
      navPresentationStyle: navPresentationStyle,
      trailing: EmptyView(),
      onDismiss: onDismiss
    )
  }
}

private struct NavigationBar<Title: View, Content: View, Trailing: View>: View {
  let backgroundColor: Color
  let content: Content
  let foregroundColor: Color
  let navPresentationStyle: NavPresentationStyle
  let onDismiss: () -> Void
  @Environment(\.presentationMode) @Binding var presentationMode
  let title: Title
  let trailing: Trailing

  var body: some View {
    VStack {
      ZStack {
        self.title.adaptiveFont(.matterMedium, size: 14)
        HStack {
          if self.navPresentationStyle == .navigation {
            Button(action: self.dismiss) {
              Image(systemName: "arrow.left")
            }
          }
          Spacer()
          if self.navPresentationStyle == .modal {
            Button(action: self.dismiss) {
              Text("Done")
                .adaptiveFont(.matterMedium, size: 14)
            }
          } else {
            self.trailing
          }
        }
      }
      .padding()

      self.content
    }
    .background(self.backgroundColor.ignoresSafeArea())
    .foregroundColor(self.foregroundColor)
    .navigationBarHidden(true)
  }

  func dismiss() {
    self.onDismiss()
    self.presentationMode.dismiss()
  }
}
