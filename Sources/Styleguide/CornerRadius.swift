import SwiftUI

extension View {
  public func adaptiveCornerRadius(_ corners: UIRectCorner, _ radius: CGFloat) -> some View {
    self.modifier(AdaptiveCornerRadius(corners: corners, radius: radius))
  }
}

private struct AdaptiveCornerRadius: ViewModifier {
  let corners: UIRectCorner
  let radius: CGFloat

  func body(content: Content) -> some View {
    content.clipShape(Bezier(corners: self.corners, radius: self.radius))
  }

  struct Bezier: Shape {
    var corners: UIRectCorner
    var radius: CGFloat

    func path(in rect: CGRect) -> Path {
      Path(
        UIBezierPath(
          roundedRect: rect,
          byRoundingCorners: self.corners,
          cornerRadii: CGSize(width: self.radius, height: self.radius)
        )
        .cgPath
      )
    }
  }
}
