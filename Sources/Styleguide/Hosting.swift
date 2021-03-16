import SwiftUI

public struct Hosting<Content>: UIViewControllerRepresentable where Content: View {
  private let configure: (UIViewController) -> Void
  private let content: Content

  public init(_ content: Content, _ configure: @escaping (UIViewController) -> Void = { _ in }) {
    self.content = content
    self.configure = configure
  }

  public func makeUIViewController(context: Context) -> UIViewController {
    let vc = UIHostingController(rootView: self.content)
    vc.view.backgroundColor = nil
    self.configure(vc)
    return vc
  }

  public func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
