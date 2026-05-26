# Stellar Mobile Build

Generated from `app-blueprint/mobile.ir.yaml`.

- Android output is a plain Gradle Android project with no Play Services dependency.
- Android direct distribution is the primary release route; Play upload is optional.
- iOS output is a SwiftUI project generated through XcodeGen.
- Remote Setup is generated as native Android and SwiftUI controls with an Stellar backend bridge client so mobile users can save the SSH target/auth details and run the same deploy, verify, TLS, test, and sync workflow.
