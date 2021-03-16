import SwiftUI

public struct ActivityView: UIViewControllerRepresentable {
  public var activityItems: [Any]

  public init(activityItems: [Any]) {
    self.activityItems = activityItems
  }

  public func makeUIViewController(context: Context) -> UIActivityViewController {
    let controller = UIActivityViewController(
      activityItems: self.activityItems,
      applicationActivities: nil
    )
    return controller
  }

  public func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context)
  {
  }
}
