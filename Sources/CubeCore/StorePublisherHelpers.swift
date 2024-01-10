import ComposableArchitecture

extension StorePublisher {
  var currentValue: State {
    var state: State!
    let cancellable = self.sink { state = $0 }
    defer { _ = cancellable }
    return state
  }
}
