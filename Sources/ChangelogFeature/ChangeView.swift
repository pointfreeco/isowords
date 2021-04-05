import ComposableArchitecture
import ServerConfigClient
import Styleguide
import SwiftUI
import UIApplicationClient

public struct ChangeState: Equatable, Identifiable {
  public var change: Changelog.Change
  public var isExpanded = false
  public var isUpdateButtonVisible = false

  public var id: Int {
    self.change.build
  }
}

public enum ChangeAction: Equatable {
  case showButtonTapped
  case updateButtonTapped
}

public struct ChangeEnvironment {
  public var applicationClient: UIApplicationClient
  public var serverConfig: ServerConfigClient
}

let changeReducer = Reducer<
  ChangeState,
  ChangeAction,
  ChangeEnvironment
> { state, action, environment in
  switch action {
  case .showButtonTapped:
    state.isExpanded.toggle()
    return .none

  case .updateButtonTapped:
    return environment.applicationClient.open(
      environment.serverConfig.config().appStoreUrl.absoluteURL,
      [:]
    )
    .fireAndForget()
  }
}

struct ChangeView: View {
  let store: Store<ChangeState, ChangeAction>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      VStack(alignment: .leading, spacing: .grid(2)) {
        HStack {
          Text(viewStore.change.version)
            .font(.title)
          Spacer()
          if !viewStore.isExpanded {
            Button(action: { viewStore.send(.showButtonTapped, animation: .default)}) {
              Text("Show")
            }
          }
        }

        if viewStore.isExpanded {
          Text(viewStore.change.log)
        }

        if viewStore.isUpdateButtonVisible {
          HStack {
            Spacer()
            Button(action: {}) {
              Text("Update")
            }
            .buttonStyle(ActionButtonStyle())
          }
        }
      }
      .adaptivePadding([.vertical])
    }
    .buttonStyle(PlainButtonStyle())
  }
}
