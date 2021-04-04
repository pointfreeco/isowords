import ApiClient
import Build
import ComposableArchitecture
import ServerConfigClient
import SharedModels
import Styleguide
import SwiftUI
import UIApplicationClient
import UserDefaultsClient

public struct ChangelogState: Equatable {
  public var changelog: [ChangeState]

  public init(
    changelog: [ChangeState] = []
  ) {
    self.changelog = changelog
  }
}

public enum ChangelogAction: Equatable {
  case change(id: Int, action: ChangeAction)
  case changelogResponse(Result<Changelog, ApiError>)
  case onAppear
}

public struct ChangelogEnvironment {
  public var apiClient: ApiClient
  public var applicationClient: UIApplicationClient
  public var build: Build
  public var mainQueue: AnySchedulerOf<DispatchQueue>
  public var serverConfig: ServerConfigClient
  public var userDefaults: UserDefaultsClient

  public init(
    apiClient: ApiClient,
    applicationClient: UIApplicationClient,
    build: Build,
    mainQueue: AnySchedulerOf<DispatchQueue>,
    serverConfig: ServerConfigClient,
    userDefaults: UserDefaultsClient
  ) {
    self.apiClient = apiClient
    self.applicationClient = applicationClient
    self.build = build
    self.mainQueue = mainQueue
    self.serverConfig = serverConfig
    self.userDefaults = userDefaults
  }
}

public let changelogReducer = Reducer<
  ChangelogState,
  ChangelogAction,
  ChangelogEnvironment
>.combine(
  changeReducer
    .forEach(
      state: \.changelog, // TODO: optional??
      action: /ChangelogAction.change(id:action:),
      environment: {
        ChangeEnvironment(
          applicationClient: $0.applicationClient,
          serverConfig: $0.serverConfig
        )
      }
    ),

  .init { state, action, environment in
    switch action {
    case .change:
      return .none

    case let .changelogResponse(.success(changelog)):
      let lastInstalledBuild = environment.userDefaults.lastInstalledBuild

      state.changelog = changelog
        .changes
        .sorted(by: { $0.build > $1.build })
        .enumerated()
        .map { offset, change in
          ChangeState(
            change: change,
            isExpanded: offset == 0 || lastInstalledBuild <= change.build,
            isUpdateButtonVisible: offset == 0 && environment.build.number() < change.build
          )
        }
      return .none

    case .changelogResponse(.failure):
      return .none

    case .onAppear:
      return environment.apiClient.apiRequest(
        route: .changelog(build: environment.build.number()),
        as: Changelog.self
      )
      .receive(on: environment.mainQueue)
      .catchToEffect()
      .map(ChangelogAction.changelogResponse)
    }
  }
)

struct ChangelogView: View {
  let store: Store<ChangelogState, ChangelogAction>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      List {
        ForEachStore(
          self.store.scope(
            state: \.changelog,
            action: ChangelogAction.change(id:action:)
          ),
          content: ChangeView.init(store:)
        )
      }
      .onAppear { viewStore.send(.onAppear) }
    }
  }
}

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

#if DEBUG
import Overture
import SwiftUIHelpers

struct ChangelogPreviews: PreviewProvider {
  static var previews: some View {
    Preview {
      ChangelogView(
        store: .init(
          initialState: .init(),
          reducer: changelogReducer,
          environment: ChangelogEnvironment(
            apiClient: update(.noop) {
              $0.override(
                routeCase: /ServerRoute.Api.Route.changelog(build:),
                withResponse: { _ in .ok(Changelog.current) }
              )
            },
            applicationClient: .noop,
            build: update(.noop) {
              $0.number = { 99 }
            },
            mainQueue: .immediate,
            serverConfig: .noop,
            userDefaults: update(.noop) {
              $0.integerForKey = { _ in 98 }
            }
          )
        )
      )
      .navigationStyle(
        title: Text("Updates"),
        navPresentationStyle: .modal,
        onDismiss: {}
      )
    }
  }
}
#endif
