import SnapshotTesting
import SwiftUI

struct AppStorePreview<SnapshotContent, Description>: View
where
  Description: View,
  SnapshotContent: View
{
  let backgroundColor: Color
  let description: () -> Description
  @Environment(\.colorScheme) var colorScheme
  @Environment(\.deviceState) var deviceState
  let snapshotContent: () -> SnapshotContent
  let snapshotting: Snapshotting<AnyView, UIImage>

  init(
    _ snapshotting: Snapshotting<AnyView, UIImage>,
    description: @escaping () -> Description,
    backgroundColor: Color,
    @ViewBuilder _ snapshotContent: @escaping () -> SnapshotContent
  ) {
    self.backgroundColor = backgroundColor
    self.description = description
    self.snapshotContent = snapshotContent
    self.snapshotting = snapshotting
  }

  var body: some View {
    ZStack {
      Group {
        if self.deviceState.idiom == .pad {
          Snapshot(self.snapshotting) {
            ZStack(alignment: .top) {
              self.snapshotContent()

              HStack {
                Text("9:41 AM")
                Spacer()
                Text("\(Image(systemName: "wifi")) 100% \(Image(systemName: "battery.100"))")
              }
              .font(Font.system(size: 12).monospacedDigit().bold())
              .foregroundColor(self.colorScheme == .dark ? .white : .black)
              .padding(.horizontal)
              .padding(.top, 3)
              .ignoresSafeArea()
            }
          }
        } else {
          Snapshot(self.snapshotting) {
            ZStack(alignment: .top) {
              self.snapshotContent()

              ZStack(alignment: .top) {
                HStack {
                  Text("9:41")
                  Spacer()
                  Text("\(Image(systemName: "wifi")) \(Image(systemName: "battery.100"))")
                }
                .font(Font.system(size: 14).monospacedDigit().bold())
                .foregroundColor(self.colorScheme == .dark ? .white : .black)
                .padding(.top, .grid(2))
                .padding(.leading, .grid(6))
                .padding(.trailing, .grid(3))

                Notch()
                  .fill(Color.black)
                  .frame(height: 25)
              }
              .ignoresSafeArea()
            }
          }
        }
      }
      .cornerRadius(.grid(self.deviceState.idiom == .pad ? 4 : 10))
      .clipped()
      .padding(.grid(self.deviceState.idiom == .pad ? 10 : 4))
      .background(Color.black)
      .cornerRadius(.grid(12))
      .overlay(
        RoundedRectangle(cornerRadius: .grid(12))
          .stroke(Color.gray, style: StrokeStyle(lineWidth: .grid(1) / 2))
      )
      .scaleEffect(self.deviceState.idiom == .pad ? 0.8 : 0.9)
      .offset(y: .grid(self.deviceState.idiom == .pad ? 90 : 60))

      VStack(spacing: .grid(self.deviceState.idiom == .pad ? 14 : 7)) {
        VStack(spacing: .grid(self.deviceState.idiom == .pad ? 14 : 7)) {
          Image(systemName: "cube.fill")
            .foregroundColor(Color.black)
            .font(.system(size: self.deviceState.idiom == .pad ? 50 : 30))

          self.description()
            .font(.custom(.matterMedium, size: self.deviceState.idiom == .pad ? 75 : 36))
            .multilineTextAlignment(.center)
        }
        .foreground(
          self.backgroundColor == .isowordsBlack
            ? LinearGradient(
              gradient: Gradient(colors: [.isowordsRed, .isowordsYellow]),
              startPoint: .bottomLeading,
              endPoint: .topTrailing
            )
            : nil
        )

        Spacer()
      }
      .padding(.horizontal, .grid(self.deviceState.idiom == .pad ? 40 : 10))
      .padding(.vertical, .grid(self.deviceState.idiom == .pad ? 12 : 4))
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(self.backgroundColor.ignoresSafeArea())
  }
}
extension View {
  @ViewBuilder
  func foreground<V: View>(_ view: V?) -> some View {
    if let view = view {
      self.overlay(view).mask(self)
    } else {
      self
    }
  }
}
struct Notch: Shape {
  func path(in rect: CGRect) -> Path {
    Path {
      let notchInset = rect.size.width * 0.23
      let smallNotchRadius: CGFloat = 7
      let scaleFactor: CGFloat = 1.6
      let notchRadius = rect.maxY / scaleFactor

      $0.move(to: .init(x: 0, y: 0))
      $0.addLine(to: .init(x: notchInset, y: 0))
      $0.addArc(
        center: .init(x: notchInset - smallNotchRadius, y: smallNotchRadius),
        radius: smallNotchRadius,
        startAngle: .init(degrees: -90),
        endAngle: .init(degrees: 0),
        clockwise: false
      )
      $0.addArc(
        center: .init(x: notchInset + notchRadius, y: notchRadius * (scaleFactor - 1)),
        radius: notchRadius,
        startAngle: .init(degrees: 180),
        endAngle: .init(degrees: 90),
        clockwise: true
      )
      $0.addLine(to: .init(x: rect.width - notchInset - notchRadius, y: rect.height))
      $0.addArc(
        center: .init(x: rect.width - notchInset - notchRadius, y: notchRadius * (scaleFactor - 1)),
        radius: notchRadius,
        startAngle: .init(degrees: 90),
        endAngle: .init(degrees: 0),
        clockwise: true
      )
      $0.addLine(to: .init(x: rect.width - notchInset, y: 0))
      $0.addArc(
        center: .init(x: rect.width - notchInset + smallNotchRadius, y: smallNotchRadius),
        radius: smallNotchRadius,
        startAngle: .init(degrees: 180),
        endAngle: .init(degrees: 270),
        clockwise: false
      )
      $0.addLine(to: .init(x: rect.width, y: 0))
      $0.closeSubpath()
    }
  }
}
