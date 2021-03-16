import SwiftUI

extension View {
  public func gradientBlend() -> some View {
    self.modifier(GradientBlend())
  }
}

private struct GradientBlend: ViewModifier {
  func body(content: Content) -> some View {
    ZStack(alignment: .top) {
      content

      // NB: Due to a bug in SwiftUI, views with the `.allowsHitTesting(false)` modifier applied
      //     still block most gestures, like scroll view panning. `UIViewControllerRepresentable`
      //     content doesn't seem to have this problem, so we can use `Hosting` to capture this
      //     gradient overlay in its own `UIHostingController` to work around this bug.
      Hosting(
        LinearGradient(
          gradient: Gradient(colors: [.hex(0xF3EBA4), .hex(0xE1665B)]),
          startPoint: .top,
          endPoint: .bottom
        )
        .ignoresSafeArea()
      )
      .ignoresSafeArea()
      .allowsHitTesting(false)
      .blendMode(.multiply)
    }
  }
}

#if DEBUG
  struct GradientBlend_Previews: PreviewProvider {
    static var previews: some View {
      ScrollView {
        VStack {
          ForEach(0...5, id: \.self) { _ in
            Text(
              """
              Lorem
              ipsum
              dolor
              sit
              amet
              """
            )
            .font(.largeTitle)
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
      .gradientBlend()
    }
  }
#endif
