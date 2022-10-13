import SnapshotTesting
import SwiftUI

func assertAppStoreSnapshots<Description, SnapshotContent>(
  for view: SnapshotContent,
  @ViewBuilder description: @escaping () -> Description,
  backgroundColor: Color,
  colorScheme: ColorScheme,
  precision: Float = 0.98,
  perceptualPrecision: Float = 0.98,
  file: StaticString = #file,
  testName: String = #function,
  line: UInt = #line
)
where
  SnapshotContent: View,
  Description: View
{
  for (name, config) in appStoreViewConfigs {
    var transaction = Transaction(animation: nil)
    transaction.disablesAnimations = true
    withTransaction(transaction) {
      assertSnapshot(
        matching: AppStorePreview(
          .image(layout: .device(config: config.viewImageConfig)),
          description: description,
          backgroundColor: backgroundColor
        ) {
          view
            .environment(\.adaptiveSize, config.adaptiveSize)
            .environment(\.colorScheme, colorScheme)
            .environment(\.deviceState, config.deviceState)
        }
        .environment(\.colorScheme, colorScheme)
        .environment(\.deviceState, config.deviceState),
        as: .image(
          precision: precision,
          perceptualPrecision: perceptualPrecision,
          layout: .device(config: config.viewImageConfig)
        ),
        named: name,
        file: file,
        testName: testName,
        line: line
      )
    }
  }
}
