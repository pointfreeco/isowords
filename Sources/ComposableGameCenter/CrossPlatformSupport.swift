#if canImport(AppKit)
  import AppKit

  public typealias ViewController = NSViewController

  extension ViewController {
    public func present() {
      NSApplication.shared.windows
        .first?
        .beginSheet(NSWindow(contentViewController: self), completionHandler: nil)
    }

    public func dismiss() {
      guard
        let sheet = NSApplication.shared.windows.first(where: { $0.contentViewController == self })
      else { return }
      NSApplication.shared.windows
        .first?
        .endSheet(sheet)
    }
  }
#endif

#if canImport(UIKit)
  import UIKit

  public typealias ViewController = UIViewController

  @available(iOSApplicationExtension, unavailable)
  extension ViewController {
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
#endif
