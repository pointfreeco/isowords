import SwiftUI

public struct DeviceState {
  public var idiom: UIUserInterfaceIdiom
  public var orientation: UIDeviceOrientation
  public var previousOrientation: UIDeviceOrientation
  public var horizontalSizeClass: UserInterfaceSizeClass?

  public static let `default` = Self(
    idiom: UIDevice.current.userInterfaceIdiom,
    orientation: UIDevice.current.orientation,
    previousOrientation: UIDevice.current.orientation,
    horizontalSizeClass: .init(UITraitCollection.current.horizontalSizeClass) ?? nil
  )

  public var isUsingPadMetrics: Bool {
      self.idiom == .pad && self.horizontalSizeClass != .compact
  }

  #if DEBUG
    public static let phone = Self(
      idiom: .phone,
      orientation: .portrait,
        previousOrientation: .portrait,
        horizontalSizeClass: .compact
    )

    public static let pad = Self(
      idiom: .pad,
      orientation: .portrait,
        previousOrientation: .portrait,
        horizontalSizeClass: .regular
    )
  #endif
}

public struct DeviceStateModifier: ViewModifier {
  @State var state: DeviceState = .default
  @Environment(\.horizontalSizeClass) var horizontalSizeClass

  public init() {
  }

  public func body(content: Content) -> some View {
    content
      .onAppear {
        self.state.horizontalSizeClass = self.horizontalSizeClass
      }
      .onChange(of: self.horizontalSizeClass, perform: { value in
        self.state.horizontalSizeClass = value
      })
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
