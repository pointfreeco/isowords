import ComposableArchitecture
import ServerConfig
import XCTest

@testable import ChangelogFeature
@testable import UserDefaultsClient

class ChangelogFeatureTests: XCTestCase {
  func testOnAppear_IsUpToDate() {
    let changelog = Changelog(
      changes: [
        .init(version: "1.2", build: 42, log: "Bug fixes and improvements"),
        .init(version: "1.1", build: 40, log: "Bug fixes and improvements"),
      ]
    )

    var environment = ChangelogEnvironment.failing
    environment.apiClient.override(
      route: .changelog(build: 42),
      withResponse: .ok(changelog)
    )
    environment.build.number = { 42 }
    environment.mainQueue = .immediate

    let store = TestStore(
      initialState: ChangelogState(),
      reducer: changelogReducer,
      environment: environment
    )

    store.send(.onAppear) {
      $0.currentBuild = 42
      $0.isRequestInFlight = true
    }
    store.receive(.changelogResponse(.success(changelog))) {
      $0.changelog = [
        .init(
          change: .init(version: "1.2", build: 42, log: "Bug fixes and improvements"),
          isExpanded: true
        ),
        .init(
          change: .init(version: "1.1", build: 40, log: "Bug fixes and improvements"),
          isExpanded: false
        )
      ]
      $0.isRequestInFlight = false
    }
  }

  func testOnAppear_IsUpBehind() {
    let changelog = Changelog(
      changes: [
        .init(version: "1.2", build: 42, log: "Bug fixes and improvements"),
        .init(version: "1.1", build: 40, log: "Bug fixes and improvements"),
        .init(version: "1.0", build: 38, log: "Bug fixes and improvements"),
      ]
    )

    var environment = ChangelogEnvironment.failing
    environment.apiClient.override(
      route: .changelog(build: 40),
      withResponse: .ok(changelog)
    )
    environment.build.number = { 40 }
    environment.mainQueue = .immediate

    let store = TestStore(
      initialState: ChangelogState(),
      reducer: changelogReducer,
      environment: environment
    )

    store.send(.onAppear) {
      $0.currentBuild = 40
      $0.isRequestInFlight = true
    }
    store.receive(.changelogResponse(.success(changelog))) {
      $0.changelog = [
        .init(
          change: .init(version: "1.2", build: 42, log: "Bug fixes and improvements"),
          isExpanded: true
        ),
        .init(
          change: .init(version: "1.1", build: 40, log: "Bug fixes and improvements"),
          isExpanded: true
        ),
        .init(
          change: .init(version: "1.0", build: 38, log: "Bug fixes and improvements"),
          isExpanded: false
        )
      ]
      $0.isRequestInFlight = false
      $0.isUpdateButtonVisible = true
    }
  }
}

extension ChangelogEnvironment {
  static let failing = Self(
    apiClient: .failing,
    applicationClient: .failing,
    build: .failing,
    mainQueue: .failing,
    serverConfig: .failing,
    userDefaults: .failing
  )
}
