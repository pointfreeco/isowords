import SwiftUI

public struct SettingsForm<Content>: View where Content: View {
  @Environment(\.colorScheme) var colorScheme
  let content: () -> Content

  public init(@ViewBuilder content: @escaping () -> Content) {
    self.content = content
  }

  public var body: some View {
    ScrollView {
      self.content()
        .adaptiveFont(.matterMedium, size: 16)
        .toggleStyle(SwitchToggleStyle(tint: .isowordsOrange))
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }
}

public struct SettingsRow<Content>: View where Content: View {
  @Environment(\.colorScheme) var colorScheme
  let content: () -> Content

  public init(@ViewBuilder content: @escaping () -> Content) {
    self.content = content
  }

  public var body: some View {
    VStack(alignment: .leading) {
      self.content()
        .padding(.vertical)
      Rectangle()
        .fill(Color.hex(self.colorScheme == .dark ? 0x7d7d7d : 0xEEEEEE))
        .frame(maxWidth: .infinity, minHeight: 2, idealHeight: 2, maxHeight: 2)
    }
    .screenEdgePadding(.horizontal)
  }
}

public struct SettingsSection<Content>: View where Content: View {
  @Environment(\.colorScheme) var colorScheme
  let content: () -> Content
  let padContents: Bool
  let title: LocalizedStringKey

  public init(
    title: LocalizedStringKey,
    padContents: Bool = true,
    @ViewBuilder content: @escaping () -> Content
  ) {
    self.content = content
    self.padContents = padContents
    self.title = title
  }

  public var body: some View {
    VStack(alignment: .leading) {
      Text(self.title)
        .padding(.bottom, 24)
        .screenEdgePadding(.horizontal)

      self.content()
        .screenEdgePadding(self.padContents ? .horizontal : [])
    }
    .padding(.bottom, 40)
  }
}
