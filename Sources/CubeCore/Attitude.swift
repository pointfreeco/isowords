// NB: Vended from ComposableCoreMotion

#if canImport(CoreMotion)
  import CoreMotion

  /// The device's orientation relative to a known frame of reference at a point in time.
  ///
  /// See the documentation for `CMAttitude` for more info.
  public struct Attitude: Hashable {
    public var quaternion: CMQuaternion

    public init(_ attitude: CMAttitude) {
      self.quaternion = attitude.quaternion
    }

    public init(quaternion: CMQuaternion) {
      self.quaternion = quaternion
    }

    @inlinable
    public func multiply(byInverseOf attitude: Self) -> Self {
      .init(quaternion: self.quaternion.multiplied(by: attitude.quaternion.inverse))
    }

    @inlinable
    public var rotationMatrix: CMRotationMatrix {
      let q = quaternion
      let s = 1 / (q.w * q.w + q.x * q.x + q.y * q.y + q.z * q.z)

      var matrix = CMRotationMatrix()

      matrix.m11 = 1 - 2 * s * (q.y * q.y + q.z * q.z)
      matrix.m12 = 2 * s * (q.x * q.y - q.z * q.w)
      matrix.m13 = 2 * s * (q.x * q.z + q.y * q.w)

      matrix.m21 = 2 * s * (q.x * q.y + q.z * q.w)
      matrix.m22 = 1 - 2 * s * (q.x * q.x + q.z * q.z)
      matrix.m23 = 2 * s * (q.y * q.z - q.x * q.w)

      matrix.m31 = 2 * s * (q.x * q.z - q.y * q.w)
      matrix.m32 = 2 * s * (q.y * q.z + q.x * q.w)
      matrix.m33 = 1 - 2 * s * (q.x * q.x + q.y * q.y)

      return matrix
    }

    @inlinable
    public var roll: Double {
      let q = quaternion
      return atan2(
        2 * (q.w * q.x + q.y * q.z),
        1 - 2 * (q.x * q.x + q.y * q.y)
      )
    }

    @inlinable
    public var pitch: Double {
      let q = quaternion
      let p = 2 * (q.w * q.y - q.z * q.x)
      return p > 1
        ? Double.pi / 2
        : p < -1
          ? -Double.pi / 2
          : asin(p)
    }

    @inlinable
    public var yaw: Double {
      let q = quaternion
      return atan2(
        2 * (q.w * q.z + q.x * q.y),
        1 - 2 * (q.y * q.y + q.z * q.z)
      )
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
      lhs.quaternion.w == rhs.quaternion.w
        && lhs.quaternion.x == rhs.quaternion.x
        && lhs.quaternion.y == rhs.quaternion.y
        && lhs.quaternion.z == rhs.quaternion.z
    }

    public func hash(into hasher: inout Hasher) {
      hasher.combine(quaternion.w)
      hasher.combine(quaternion.x)
      hasher.combine(quaternion.y)
      hasher.combine(quaternion.z)
    }
  }

  extension CMQuaternion {
    @usableFromInline
    var inverse: CMQuaternion {
      let invSumOfSquares =
        1 / (x * x + y * y + z * z + w * w)
      return CMQuaternion(
        x: -x * invSumOfSquares,
        y: -y * invSumOfSquares,
        z: -z * invSumOfSquares,
        w: w * invSumOfSquares
      )
    }

    @usableFromInline
    func multiplied(by other: Self) -> Self {
      var result = self
      result.w = w * other.w - x * other.x - y * other.y - z * other.z
      result.x = w * other.x + x * other.w + y * other.z - z * other.y
      result.y = w * other.y - x * other.z + y * other.w + z * other.x
      result.z = w * other.z + x * other.y - y * other.x + z * other.w
      return result
    }
  }
#endif
