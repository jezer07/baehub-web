# Baehub Native iOS (Starter)

## Requirements

- Xcode 16+
- iOS 16+

## Dependencies

Add Swift Package dependency in Xcode:

- `https://github.com/hotwired/hotwire-native-ios`

## Configure base URL

Edit both files and set URL:

- `BaehubNative/AppDelegate.swift`
- `BaehubNative/SceneDelegate.swift`

Values:

- Simulator: `http://localhost:3000`
- Device: `http://<your-lan-ip>:3000`

## Run

1. Start Rails: `bin/rails server -b 0.0.0.0 -p 3000`
2. Open/create Xcode project at this directory.
3. Add Hotwire Native package dependency.
4. Include `BaehubNative/Resources/path-configuration.json` in app bundle.
5. Build and run.
