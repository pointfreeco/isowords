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
      if self.isLoaded {
        GeometryReader { outer in
          ScrollView(.horizontal) {
            HStack(spacing: outer.size.width * 2 / 3) {
              Color.clear
                .frame(width: outer.size.width * 1 / 3)
              self.messages()
            }
            .fixedSize()
            .offset(x: -self.size.width)
            .animation(
              Animation
                .linear(duration: self.duration)
                .repeatForever(autoreverses: false),
              value: self.size.width
            )
            .background(
              GeometryReader { inner in
                Color.clear
                  .onAppear { self.size = inner.size }
              }
            )
          }
          .disabled(true)
        }
        .frame(height: self.size.height)
      }
    }
    .frame(maxWidth: .infinity)
    .onAppear {
      DispatchQueue.main.async {
        self.isLoaded = true
      }
    }
  }
}
