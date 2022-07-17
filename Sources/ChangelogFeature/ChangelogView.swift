import ApiClient
import Build
import ComposableArchitecture
import ServerConfigClient
import SharedModels
import Styleguide
import SwiftUI
import TcaHelpers
import UIApplicationClient
import UserDefaultsClient

public struct ChangelogState: Equatable {
  public var changelog: IdentifiedArrayOf<ChangeState>
  public var currentBuild: Build.Number
  public var isRequestInFlight: Bool
  public var isUpdateButtonVisible: Bool

  public init(
    changelog: IdentifiedArrayOf<ChangeState> = [],
    currentBuild: Build.Number = 0,
    isRequestInFlight: Bool = false,
    isUpdateButtonVisible: Bool = false
  ) {
    self.changelog = changelog
    self.currentBuild = currentBuild
    self.isRequestInFlight = isRequestInFlight
    self.isUpdateButtonVisible = isUpdateButtonVisible
  }
}

public enum ChangelogAction: Equatable {
  case change(id: Build.Number, action: ChangeAction)
  case changelogResponse(TaskResult<Changelog>)
  case task
  case updateButtonTapped
}

public struct ChangelogEnvironment {
  public var apiClient: ApiClient
  public var applicationClient: UIApplicationClient
  public var build: Build
  public var serverConfig: ServerConfigClient
  public var userDefaults: UserDefaultsClient

  public init(
    apiClient: ApiClient,
    applicationClient: UIApplicationClient,
    build: Build,
    serverConfig: ServerConfigClient,
    userDefaults: UserDefaultsClient
  ) {
    self.apiClient = apiClient
    self.applicationClient = applicationClient
    self.build = build
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
      state: \ChangelogState.changelog,
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
      state.changelog = IdentifiedArray(
        uniqueElements:
          changelog
          .changes
          .sorted(by: { $0.build > $1.build })
          .enumerated()
          .map { offset, change in
            ChangeState(
              change: change,
              isExpanded: offset == 0 || environment.build.number() <= change.build
            )
          }
      )
      state.isRequestInFlight = false
      state.isUpdateButtonVisible =
        environment.build.number() < (changelog.changes.map(\.build).max() ?? 0)

      return .none

    case .changelogResponse(.failure):
      state.isRequestInFlight = false
      return .none

    case .task:
      state.currentBuild = environment.build.number()
      state.isRequestInFlight = true

      return .task {
        await .changelogResponse(
          TaskResult {
            try await environment.apiClient.apiRequestAsync(
              route: .changelog(build: environment.build.number()),
              as: Changelog.self
            )
          }
        )
      }

    case .updateButtonTapped:
      return .fireAndForget {
        _ = await environment.applicationClient.openAsync(
          environment.serverConfig.config().appStoreUrl.absoluteURL,
          [:]
        )
      }
    }
  }
)

public struct ChangelogView: View {
  let store: Store<ChangelogState, ChangelogAction>

  struct ViewState: Equatable {
    let currentBuild: Build.Number
    let isUpdateButtonVisible: Bool

    init(state: ChangelogState) {
      self.currentBuild = state.currentBuild
      self.isUpdateButtonVisible = state.isUpdateButtonVisible
    }
  }

  public init(
    store: Store<ChangelogState, ChangelogAction>
  ) {
    self.store = store
  }

  public var body: some View {
    WithViewStore(self.store.scope(state: ViewState.init)) { viewStore in
      ScrollView {
        VStack(alignment: .leading) {
          if viewStore.isUpdateButtonVisible {
            HStack {
              Spacer()
              Button(action: { viewStore.send(.updateButtonTapped) }) {
                Text("Update")
              }
              .buttonStyle(ActionButtonStyle())
            }
          }

          Text("What's new?")
            .font(.largeTitle)

          ForEachStore(
            self.store.scope(
              state: { $0.changelog.filter { $0.change.build >= viewStore.currentBuild } },
              action: ChangelogAction.change(id:action:)
            ),
            content: { ChangeView(currentBuild: viewStore.currentBuild, store: $0) }
          )

          Text("Past updates")
            .font(.largeTitle)

          ForEachStore(
            self.store.scope(
              state: { $0.changelog.filter { $0.change.build < viewStore.currentBuild } },
              action: ChangelogAction.change(id:action:)
            ),
            content: { ChangeView(currentBuild: viewStore.currentBuild, store: $0) }
          )
        }
        .padding()
      }
      .task { await viewStore.send(.task).finish() }
    }
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
                  withResponse: { _ in
                    try await OK(
                      update(Changelog.current) {
                        $0.changes.append(
                          Changelog.Change(
                            version: "1.0",
                            build: 60,
                            log: "We launched!"
                          )
                        )
                      }
                    )
                  }
                )
              },
              applicationClient: .noop,
              build: update(.noop) {
                $0.number = { 98 }
              },
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
