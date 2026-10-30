import SwiftUI

class NubUIView: UIView {
  var isPressed: Bool = false {
    didSet {
      render()
    }
  }

  override init(frame: CGRect) {
    super.init(frame: .init(x: 0, y: 0, width: 60, height: 60))

    self.backgroundColor = UIColor.white.withAlphaComponent(0.85)
    self.layer.borderColor = UIColor.black.withAlphaComponent(0.35).cgColor
    self.layer.cornerRadius = 30
    self.render()
  }

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    super.touchesBegan(touches, with: event)
    isPressed = true
  }

  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    super.touchesEnded(touches, with: event)
    isPressed = false
  }

  func render() {
    let duration = isPressed ? 0 : 0.3
    UIView.animate(withDuration: duration) {
      CATransaction.begin()
      if isPressed {
        layer.borderWidth = 4
        layer.shadowOffset = .zero
        layer.shadowOpacity = 0
        layer.shadowRadius = 0
        layer.removeAnimation(forKey: "borderWidth")
      } else {
        layer.borderWidth = 0
        layer.shadowOffset = .init(width: 0, height: 2)
        layer.shadowOpacity = 1
        layer.shadowRadius = 3
        let borderWidth = CABasicAnimation(keyPath: "borderWidth")
        borderWidth.fromValue = 4
        borderWidth.toValue = 0
        borderWidth.duration = 0.3
        layer.add(borderWidth, forKey: "borderWidth")
      }
      CATransaction.commit()
    }
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

struct NubStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    Circle()
      .strokeBorder(Color.black.opacity(0.35), lineWidth: configuration.isPressed ? 6 : 0)
      .background(
        Circle()
          .foregroundColor(Color.white.opacity(0.85))
      )
      .frame(width: 60, height: 60, alignment: .center)
      .shadow(
        color: configuration.isPressed ? .clear : .black, radius: configuration.isPressed ? 0 : 3,
        y: configuration.isPressed ? 0 : 2)
  }
}

struct NubViewPreviews: PreviewProvider {
  static var previews: some View {
    ZStack {
      VStack {
        Rectangle()
          .fill(Color.blue)
          .frame(width: 100, height: 100)

        Rectangle()
          .fill(Color.blue)
          .frame(width: 100, height: 100)

        Rectangle()
          .fill(Color.blue)
          .frame(width: 100, height: 100)
      }
      VStack(spacing: 50) {
        Button {
        } label: {
        }
        .buttonStyle(NubStyle())

        UIViewRepresenting(NubUIView())
          .frame(width: 60, height: 60)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.white)
  }
}

struct UIViewRepresenting<View: UIView>: UIViewRepresentable {
  let view: View

  init(_ view: View) {
    self.view = view
  }

  func makeUIView(context: Context) -> View {
    view
  }

  func updateUIView(_ uiView: View, context: Context) {}
}
