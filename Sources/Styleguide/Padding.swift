import SwiftUI

extension View {
  public func adaptivePadding(_ edges: Edge.Set = .all, _ length: CGFloat? = nil) -> some View {
    self.modifier(AdaptivePadding(configuration: .edges(edges, length: length)))
  }

  public func adaptivePadding(_ edgeInsets: EdgeInsets) -> some View {
    self.modifier(AdaptivePadding(configuration: .edgeInsets(edgeInsets)))
  }

  public func screenEdgePadding(_ edges: Edge.Set = []) -> some View {
    self.modifier(ScreenEdgePadding(edges: edges))
  }
}

private struct ScreenEdgePadding: ViewModifier {
  @Environment(\.deviceState) var deviceState
  let edges: Edge.Set

  @ViewBuilder
  func body(content: Content) -> some View {
    switch self.deviceState.idiom {
    case .unspecified, .phone, .carPlay:
      content.adaptivePadding(self.edges)

    case .pad, .tv, .mac:
      content.adaptivePadding(
        self.edges,
        // NB: clean this up by holding onto previous "valid" orientation.
        iPadPadding(for: self.deviceState.orientation)
          ?? iPadPadding(for: self.deviceState.previousOrientation)
          ?? .grid(20)
      )

    @unknown default:
      content
    }
  }

  func iPadPadding(for orientation: UIDeviceOrientation) -> CGFloat? {
    switch orientation {
    case .portrait, .portraitUpsideDown:
      return .grid(20)

    case .landscapeLeft, .landscapeRight:
      return .grid(40)

    case .unknown, .faceUp, .faceDown:
      return nil

    @unknown default:
      return nil
    }
  }
}

private struct AdaptivePadding: ViewModifier {
  enum Configuration {
    case edgeInsets(EdgeInsets)
    case edges(Edge.Set, length: CGFloat?)
  }

  @Environment(\.adaptiveSize) var adaptiveSize

  let configuration: Configuration

  @ViewBuilder
  func body(content: Content) -> some View {
    switch self.configuration {
    case let .edgeInsets(edgeInsets):
      content.padding(edgeInsets.apply(self.adaptiveSize))
    case let .edges(edges, .some(length)):
      content.padding(edges, length + self.adaptiveSize.padding)
    case let .edges(edges, .none):
      content.padding(edges).padding(edges, self.adaptiveSize.padding)
    }
  }
}

extension EdgeInsets {
  fileprivate func apply(_ adaptiveSize: AdaptiveSize) -> EdgeInsets {
    EdgeInsets(
      top: self.top == 0 ? 0 : self.top + adaptiveSize.padding,
      leading: self.leading == 0 ? 0 : self.leading + adaptiveSize.padding,
      bottom: self.bottom == 0 ? 0 : self.bottom + adaptiveSize.padding,
      trailing: self.trailing == 0 ? 0 : self.trailing + adaptiveSize.padding
    )
  }
}
