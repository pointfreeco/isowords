import SwiftUI
import UIKit

class ConfettiView: UIView {
  init(foregroundColor: UIColor) {
    super.init(frame: .zero)

    self.isUserInteractionEnabled = false

    class ConfettiType {
      let color: UIColor
      let position: ConfettiPosition

      init(color: UIColor, position: ConfettiPosition) {
        self.color = color
        self.position = position
      }

      lazy var name = UUID().uuidString

      lazy var image: UIImage = {
        let rect = CGRect(x: 0, y: 0, width: 13, height: 20)

        UIGraphicsBeginImageContext(rect.size)
        let context = UIGraphicsGetCurrentContext()!
        context.setFillColor(color.cgColor)

        context.rotate(by: .random(in: 0 ... .pi/2))
        context.move(to: .zero)
        context.addLine(to: .init(x: rect.maxX, y: 0))
        context.addLine(to: .init(x: rect.midX, y: rect.maxY))
        context.fillPath()

        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image!
      }()
    }

    enum ConfettiPosition {
      case foreground
      case background
    }

    let confettiTypes: [ConfettiType] = {
      let confettiColors = [
        foregroundColor,
      ]

      return [ConfettiPosition.foreground, ConfettiPosition.background].flatMap { position in
        return confettiColors.map { color in
          return ConfettiType(color: color, position: position)
        }
      }
    }()

    func createConfettiCells() -> [CAEmitterCell] {
      return confettiTypes.map { confettiType in
        let cell = CAEmitterCell()
        cell.name = confettiType.name

        cell.beginTime = 0.1
        cell.birthRate = 100
        cell.contents = confettiType.image.cgImage
        cell.emissionRange = CGFloat(Double.pi)
        cell.lifetime = 10
        cell.spin = 4
        cell.spinRange = 8
        cell.velocityRange = 0
        cell.yAcceleration = 0

        cell.setValue("plane", forKey: "particleType")
        cell.setValue(Double.pi, forKey: "orientationRange")
        cell.setValue(Double.pi / 2, forKey: "orientationLongitude")
        cell.setValue(Double.pi / 2, forKey: "orientationLatitude")

        return cell
      }
    }

    func createBehavior(type: String) -> NSObject {
      let behaviorClass = NSClassFromString("CAEmitterBehavior") as! NSObject.Type
      let behaviorWithType = behaviorClass.method(for: NSSelectorFromString("behaviorWithType:"))!
      let castedBehaviorWithType = unsafeBitCast(behaviorWithType, to:(@convention(c)(Any?, Selector, Any?) -> NSObject).self)
      return castedBehaviorWithType(behaviorClass, NSSelectorFromString("behaviorWithType:"), type)
    }

    func horizontalWaveBehavior() -> Any {
      let behavior = createBehavior(type: "wave")
      behavior.setValue([100, 0, 0], forKeyPath: "force")
      behavior.setValue(0.5, forKeyPath: "frequency")
      return behavior
    }

    func verticalWaveBehavior() -> Any {
      let behavior = createBehavior(type: "wave")
      behavior.setValue([0, 500, 0], forKeyPath: "force")
      behavior.setValue(3, forKeyPath: "frequency")
      return behavior
    }

    func attractorBehavior(for emitterLayer: CAEmitterLayer) -> Any {
      let behavior = createBehavior(type: "attractor")
      behavior.setValue("attractor", forKeyPath: "name")

      behavior.setValue(-290, forKeyPath: "falloff")
      behavior.setValue(300, forKeyPath: "radius")
      behavior.setValue(10, forKeyPath: "stiffness")

      behavior.setValue(CGPoint(x: emitterLayer.emitterPosition.x,
                                y: emitterLayer.emitterPosition.y + 20),
                        forKeyPath: "position")
      behavior.setValue(-70, forKeyPath: "zPosition")

      return behavior
    }

    func addBehaviors(to layer: CAEmitterLayer) {
      layer.setValue([
        horizontalWaveBehavior(),
        verticalWaveBehavior(),
        attractorBehavior(for: layer)
      ], forKey: "emitterBehaviors")
    }

    func addAttractorAnimation(to layer: CALayer) {
      let animation = CAKeyframeAnimation()
      animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
      animation.duration = 3
      animation.keyTimes = [0, 0.4]
      animation.values = [80, 5]

      layer.add(animation, forKey: "emitterBehaviors.attractor.stiffness")
    }

    func addBirthrateAnimation(to layer: CALayer) {
      let animation = CABasicAnimation()
      animation.duration = 0.35
      animation.fromValue = 1
      animation.toValue = 0

      layer.add(animation, forKey: "birthRate")
    }

    func addAnimations(to layer: CAEmitterLayer) {
      addAttractorAnimation(to: layer)
      addBirthrateAnimation(to: layer)
      addGravityAnimation(to: layer)
    }

    func dragBehavior() -> Any {
      let behavior = createBehavior(type: "drag")
      behavior.setValue("drag", forKey: "name")
      behavior.setValue(2, forKey: "drag")

      return behavior
    }

    func addDragAnimation(to layer: CALayer) {
      let animation = CABasicAnimation()
      animation.duration = 0.35
      animation.fromValue = 0
      animation.toValue = 2

      layer.add(animation, forKey:  "emitterBehaviors.drag.drag")
    }

    func addGravityAnimation(to layer: CALayer) {
      let animation = CAKeyframeAnimation()
      animation.duration = 6
      animation.keyTimes = [0.05, 0.1, 0.5, 1]
      animation.values = [0, 100, 2000, 4000]

      for image in confettiTypes {
        layer.add(animation, forKey: "emitterCells.\(image.name).yAcceleration")
      }
    }

    func createConfettiLayer() -> CAEmitterLayer {
      let emitterLayer = CAEmitterLayer()

      emitterLayer.birthRate = 0
      emitterLayer.emitterCells = createConfettiCells()
      emitterLayer.emitterPosition = CGPoint(x: self.bounds.midX, y: self.bounds.minY - 100)
      emitterLayer.emitterSize = CGSize(width: 100, height: 100)
      emitterLayer.emitterShape = .sphere
      emitterLayer.frame = self.bounds

      emitterLayer.beginTime = CACurrentMediaTime()
      return emitterLayer
    }

    let foregroundConfettiLayer = createConfettiLayer()

    let backgroundConfettiLayer: CAEmitterLayer = {
      let emitterLayer = createConfettiLayer()

      for emitterCell in emitterLayer.emitterCells ?? [] {
        emitterCell.scale = 0.5
      }

      emitterLayer.opacity = 0.5
      emitterLayer.speed = 0.95

      return emitterLayer
    }()

    for layer in [foregroundConfettiLayer, backgroundConfettiLayer] {
      self.layer.addSublayer(layer)
      addBehaviors(to: layer)
      addAnimations(to: layer)
    }
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

struct ConfettiRepresentable: UIViewRepresentable {
  let foregroundColor: Color

  typealias UIViewType = UIView

  func makeUIView(context: Context) -> UIView {
    ConfettiView(foregroundColor: UIColor(self.foregroundColor))
  }

  func updateUIView(_ uiView: UIView, context: Context) {}
}

struct Confetti: View {
  let foregroundColor: Color

  var body: some View {
    ConfettiRepresentable(foregroundColor: self.foregroundColor)
      .frame(width: 0, height: 0)
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    Confetti(foregroundColor: .adaptiveBlack)
      .frame(width: 0, height: 0, alignment: .center)
  }
}
