import Combine
import Foundation
import SharedModels

public func apiDecode<A: Decodable>(_ type: A.Type, from data: Data) throws -> A {
  do {
    return try jsonDecoder.decode(A.self, from: data)
  } catch let decodingError {
    let apiError: Error
    do {
      apiError = try jsonDecoder.decode(ApiError.self, from: data)
    } catch {
      throw decodingError
    }
    throw apiError
  }
}
