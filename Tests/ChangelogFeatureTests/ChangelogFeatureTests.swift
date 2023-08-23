import ApiClient
import ComposableArchitecture
import ServerConfig
import XCTest

@testable import ChangelogFeature
@testable import UserDefaultsClient

@MainActor
class ChangelogFeatureTests: XCTestCase {
  func testOnAppear_IsUpToDate() async {
    let changelog = Changelog(
      changes: [
        .init(version: "1.2", build: 42, log: "Bug fixes and improvements"),
        .init(version: "1.1", build: 40, log: "Bug fixes and improvements"),
      ]
    )

    let store = TestStore(initialState: ChangelogReducer.State()) {
      ChangelogReducer()
    } withDependencies: {
      $0.apiClient.override(
        route: .changelog(build: 42),
        withResponse: { try await OK(changelog) }
      )
      $0.build.number = { 42 }
    }

    await store.send(.task) {
      $0.currentBuild = 42
      $0.isRequestInFlight = true
    }
    await store.receive(.changelogResponse(.success(changelog))) {
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

  func testOnAppear_IsUpBehind() async {
    let changelog = Changelog(
      changes: [
        .init(version: "1.2", build: 42, log: "Bug fixes and improvements"),
        .init(version: "1.1", build: 40, log: "Bug fixes and improvements"),
        .init(version: "1.0", build: 38, log: "Bug fixes and improvements"),
      ]
    )

    let store = TestStore(initialState: ChangelogReducer.State()) {
      ChangelogReducer()
    } withDependencies: {
      $0.apiClient.override(
        route: .changelog(build: 40),
        withResponse: { try await OK(changelog) }
      )
      $0.build.number = { 40 }
    }

    await store.send(.task) {
      $0.currentBuild = 40
      $0.isRequestInFlight = true
    }
    await store.receive(.changelogResponse(.success(changelog))) {
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
