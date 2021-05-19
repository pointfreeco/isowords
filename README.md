# isowords

[![CI](https://github.com/pointfreeco/isowords/actions/workflows/ci.yml/badge.svg)](https://github.com/pointfreeco/isowords/actions/workflows/ci.yml)

This repo contains the full source code for [isowords](https://www.isowords.xyz), an iOS word search game played on a vanishing cube. Connect touching letters to form words, the longer the better, and the third time a letter is used its cube is removed, revealing more letters inside!

Available on the [App Store](https://www.isowords.xyz/app-store) now!

[![Download isowords on the App Store](https://dbsqho33cgp4y.cloudfront.net/github/app-store-badge.png)](https://www.isowords.xyz/app-store)

[![isowords screenshots](https://dbsqho33cgp4y.cloudfront.net/github/isowords-screenshots.jpg)](https://www.isowords.xyz/app-store)

---

* [About](#about)
* [Getting Started](#getting-started)
* [Learn More](#learn-more)
* [Related Projects](#related-projects)
* [License](#license)

# About

[isowords](https://www.isowords.xyz) is a large, complex application built entirely in Swift. The iOS client's logic is built in the [Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture) and the UI is built mostly in SwiftUI with a little bit in SceneKit. The server is also built in Swift using our experimental web server libraries.

We published a [4-part series of videos](https://www.pointfree.co/collections/tours/isowords) covering these topics and more on [Point-Free](https://www.pointfree.co), a video series exploring functional programming and the Swift language, hosted by [Brandon Williams](https://twitter.com/mbrandonw) and [Stephen Celis](https://twitter.com/stephencelis).

<a href="https://www.pointfree.co/collections/tours/isowords">
  <img alt="video poster image" src="https://i.vimeocdn.com/video/1127151635.jpg" width="600">
</a>

<br><br>

Some things you might find interesting:

### The Composable Architecture

The whole application is powered by the [Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture), a library we built from scratch on [Point-Free](https://www.pointfree.co/collections/composable-architecture) that provides tools for building applications with a focus on composability, modularity, and testability. This means:

* The entire app's state is held in a single source of truth, called a `Store`.
* The entire app's behavior is implemented by a single unit, called a `Reducer`, which is composed out of many other reducers.
* All effectful operations are made explicit as values returned from reducers.
* Dependencies are made explicit as simple data types wrapping their live implementations, along with various mock instances.

There are a ton of benefits to designing applications in this manner:

* Large, complex features can be broken down into smaller child domains, and those domains can communicate via simple state mutations. Typically this is done in SwiftUI by accessing singletons inside `ObservableObject` instances, but this is not necessary in the Composable Architecture.
* We take control of dependencies rather than allow them to take control of us. Just because you are using `StoreKit`, `GameCenter`, `UserNotifications`, or any other 3rd party APIs in your code, it doesn't mean you should sacrifice your ability to run your app in the simulator, SwiftUI previews, or write concise tests.
* Exhaustive tests can be written very quickly. We test very detailed user flows, capture subtle edge cases, and assert on how effects execute and how their outputs feed back into the application.
* It is straightforward to write integration tests that exercise multiple independent parts of the application.

### Hyper-modularization

The application is built in a hyper-modularized style. At the time of writing this README the client and server are split into [86 modules](https://github.com/pointfreeco/isowords/blob/main/Package.swift). This allows us to work on features without building the entire application, which improves compile times and SwiftUI preview stability. It also made it easy for us to ship an App Clip, whose size must be less than 10 MB _uncompressed_, by choosing the bare minimum of code and resources to build.

### Client/Server monorepo

The code for both the iOS client and server are included in this single repository. This makes it easy to run both the client and server at the same time, and we can even debug them at the same time, e.g. set breakpoints in the server that are triggered when the simulator makes API requests.

We also share a lot of code between client and server:

* The core types that describe players, puzzles, moves, etc.
* Game logic, such as the random puzzle generator, puzzle verification, dictionaries, and more.
* The router used for handling requests on the server is the exact same code the iOS client uses to make API requests to the server. New routes only have to be specified a single time and it is immediately available to both client and server.
* We write integration tests that simultaneously test the server and iOS client. During a test, API requests made by the client are actually running real server code under the hood.
* And more...

### Automated App Store screenshots and previews

The screenshots and preview video that we upload to the [App Store](https://www.isowords.xyz/app-store) for this app are automatically generated.

* The [screenshots](https://github.com/pointfreeco/isowords/blob/main/Tests/AppStoreSnapshotTests/__Snapshots__/AppStoreSnapshotTests) are generated by a [test suite](https://github.com/pointfreeco/isowords/blob/main/Tests/AppStoreSnapshotTests) using our [SnapshotTesting](https://github.com/pointfreeco/swift-snapshot-testing) library, and do the work of constructing a very specific piece of state that we load into a screen, as well as framing the UI and providing the surrounding graphics.

* The preview [video](https://apptrailers.itunes.apple.com/itunes-assets/PurpleVideo124/v4/e7/c1/8e/e7c18e28-b229-a8a7-b5b7-f151f920ae91/P233871875_default.m3u8) is generated as a screen recording of running a [slimmed-down version](https://github.com/pointfreeco/isowords/blob/main/Sources/TrailerFeature) of the app that embeds specific letters onto a cube and runs a sequence of actions to emulate a user playing the game. The app can be run locally by selecting the `TrailerPreview` target in Xcode and running it in the simulator.

### Preview apps

There are times that we want to test a feature in isolation without building the entire app. SwiftUI previews are great for this but also have their limitations, such as if you need to use APIs unavailable to previews, or if you need to debug more complex flows, etc.

So, we create [mini-applications](https://github.com/pointfreeco/isowords/blob/main/App/Previews) that build a small subset of the [86+ modules](https://github.com/pointfreeco/isowords/blob/main/Package.swift) that comprise the entire application. Setting up these applications requires minimal work. You just specify what dependencies you need in the Xcode project and then create an entry point to launch the feature.

For example, [here](https://github.com/pointfreeco/isowords/blob/main/App/Previews/OnboardingPreview/OnboardingPreviewApp.swift) is all the code necessary to create a preview app for running the onboarding flow in isolation. If we were at the whims of the full application to test this feature we would need to constantly delete and reinstall the app since this screen is only shown on first launch.

# Getting Started

This repo contains both the client and server code for running the entire [isowords](https://www.isowords.xyz) application, as well as an extensive test suite. To get things running:

1. Make sure [`git-lfs`](https://git-lfs.github.com) is installed so that app assets (images, etc.) can be fetched.
1. Grab the code:
    ```sh
    git clone https://github.com/pointfreeco/isowords
    cd isowords
    ```
1. Bootstrap the application:
    1. If you are only interested in building the iOS client, then run the following bootstrap command:
        ```sh
        make bootstrap-client
        ```
    1. If you want to build the client and server make sure [PostgreSQL](https://www.postgresql.org/) is installed and running, and then run the following bootstrap command:
        ```sh
        make bootstrap
        ```
1. Open the Xcode workspace `isowords.xcworkspace`.
1. To run the client locally, select the `isowords` target in Xcode and run (`⌘R`).
1. To run the server locally, select the `server` target in Xcode and run (`⌘R`).

# Learn More

Most of the concepts discussed in this README are covered in-depth on [Point-Free](https://www.pointfree.co), a video series exploring functional programming and the Swift language, hosted by [Brandon Williams](https://www.twitter.com/mbrandonw) and [Stephen Celis](https://www.twitter.com/stephencelis).

[![Point-Free](https://dbsqho33cgp4y.cloudfront.net/github/point-free-header.png)](https://www.pointfree.co)

# Related Projects

This application makes use of a number of open source projects built by us and discussed on [Point-Free](https://www.pointfree.co), including:

* [Case Paths](https://github.com/pointfreeco/swift-case-paths)
* [Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture.git)
* [Gen](https://github.com/pointfreeco/swift-gen.git)
* [Overture](https://github.com/pointfreeco/swift-overture.git)
* [Tagged](https://github.com/pointfreeco/swift-tagged.git)
* [SnapshotTesting](https://github.com/pointfreeco/swift-snapshot-testing.git)

# License

The source code in this repository may be run and altered for education purposes only and not for commercial purposes. For more information see our full [license](LICENSE.md).
