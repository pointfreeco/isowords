import Combine
import UIKit

@available(iOSApplicationExtension, unavailable)
extension UIApplicationClient {
  public static let live = Self(
    alternateIconName: { UIApplication.shared.alternateIconName },
    alternateIconNameAsync: { await UIApplication.shared.alternateIconName },
    open: { url, options in
      .future { callback in
        UIApplication.shared.open(url, options: options) { bool in
          callback(.success(bool))
        }
      }
    },
    openAsync: { await UIApplication.shared.open($0, options: $1) },
    openSettingsURLString: { UIApplication.openSettingsURLString },
    openSettingsURLStringAsync: { await UIApplication.openSettingsURLString },
    setAlternateIconName: { iconName in
      .run { subscriber in
        UIApplication.shared.setAlternateIconName(iconName) { error in
          if let error = error {
            subscriber.send(completion: .failure(error))
          } else {
            subscriber.send(completion: .finished)
          }
        }
        return AnyCancellable {}
      }
    },
    setAlternateIconNameAsync: { try await UIApplication.shared.setAlternateIconName($0) },
    supportsAlternateIcons: { UIApplication.shared.supportsAlternateIcons },
    supportsAlternateIconsAsync: { await UIApplication.shared.supportsAlternateIcons }
  )
}
