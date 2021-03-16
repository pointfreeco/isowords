# App Targets

This directory contains all of the app targets that can be actually run in the simulator or on a device. There isn't much in these targets because all code and resources are in [SPM modules](../Package.swift). Some things you might be interested in:

* [AppClip](AppClip): Contains the entry point for the AppClip that ships with the game. All of the code for the app clip is contained in the [`DemoFeature`](../Sources/DemoFeature) module, and so all the entry point has to do is create the `DemoView`.

* [Previews](Previews): Contains a bunch of app targets that allow us to run specific features in isolation without building the entire application at once. This also gives us a great opportunity to substitute in hand crafted state and dependencies so that we can play with specific edge cases without having to hard code that data into the real, shippable app.
