import SwiftUI

struct Marquee<Content>: View where Content: View {
  let duration: TimeInterval
  let messages: () -> Content

  init(
    duration: TimeInterval,
    @ViewBuilder messages: @escaping () -> Content
  ) {
    self.duration = duration
    self.messages = messages
  }

  @State private var isLoaded = false
  @State private var size: CGSize = .zero

  var body: some View {
    VStack {
      if isLoaded {
        GeometryReader { outer in
          ScrollView(.horizontal) {
            HStack(spacing: outer.size.width * 2 / 3) {
              Color.clear
                .frame(width: outer.size.width * 1 / 3)
              messages()
            }
            .fixedSize()
            .offset(x: -size.width)
            .animation(
              Animation
                .linear(duration: duration)
                .repeatForever(autoreverses: false),
              value: size.width
            )
            .background(
              GeometryReader { inner in
                Color.clear
                  .onAppear { size = inner.size }
              }
            )
          }
          .disabled(true)
        }
        .frame(height: size.height)
      }
    }
    .frame(maxWidth: .infinity)
    .onAppear {
      DispatchQueue.main.async {
        isLoaded = true
      }
    }
  }
}
