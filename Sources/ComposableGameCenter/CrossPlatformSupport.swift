import UIKit

@available(iOSApplicationExtension, unavailable)
extension UIViewController {
  public func present() {
    UIApplication.shared.windows
      .first(where: \.isKeyWindow)?
      .rootViewController?
      .present(self, animated: true)
  }

  public func dismiss() {
    self.dismiss(animated: true, completion: nil)
  }
}
