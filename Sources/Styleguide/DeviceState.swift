import SwiftUI

public struct DeviceState {
  public var idiom: UIUserInterfaceIdiom
  public var orientation: UIDeviceOrientation
  public var previousOrientation: UIDeviceOrientation

  public static let `default` = Self(
    idiom: UIDevice.current.userInterfaceIdiom,
    orientation: UIDevice.current.orientation,
    previousOrientation: UIDevice.current.orientation
  )

  public var isPad: Bool {
    self.idiom == .pad
  }

  public var isPhone: Bool {
    self.idiom == .phone
  }

  #if DEBUG
    public static let phone = Self(
      idiom: .phone,
      orientation: .portrait,
      previousOrientation: .portrait
    )

    public static let pad = Self(
      idiom: .pad,
      orientation: .portrait,
      previousOrientation: .portrait
    )
  #endif
}

public struct DeviceStateModifier: ViewModifier {
  @State var state: DeviceState = .default

  public init() {
  }

  public func body(content: Content) -> some View {
    content
      .onAppear()
      .onReceive(
        NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)
      ) { _ in
        self.state.previousOrientation = self.state.orientation
        self.state.orientation = UIDevice.current.orientation
      }
      .environment(\.deviceState, self.state)
  }
}

extension EnvironmentValues {
  public var deviceState: DeviceState {
    get { self[DeviceStateKey.self] }
    set { self[DeviceStateKey.self] = newValue }
  }
}

private struct DeviceStateKey: EnvironmentKey {
  static var defaultValue: DeviceState {
    .default
  }
}
