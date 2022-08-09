#if os(iOS)
  import UIKit

  @available(iOSApplicationExtension, unavailable)
  extension UIViewController {
    public func present() {
      guard
        let scene = UIKit.UIApplication.shared.connectedScenes.first(where: { $0 is UIWindowScene })
      as? UIWindowScene
      else { return }
      scene.keyWindow?.rootViewController?.present(self, animated: true)
    }

    public func dismiss() {
      self.dismiss(animated: true, completion: nil)
    }
  }
#endif
