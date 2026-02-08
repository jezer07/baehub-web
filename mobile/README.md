# Mobile (Hotwire Native)

This directory contains starter projects for iOS and Android wrappers around the Rails app.

## Backend first

Run the Rails server from the repository root:

```bash
bin/rails server -b 0.0.0.0 -p 3000
```

Verify path configs:

```bash
curl http://localhost:3000/configurations/ios_v1.json
curl http://localhost:3000/configurations/android_v1.json
```

## iOS

Project location:

- `mobile/ios/BaehubNative`

Open in Xcode and set your Team/Bundle ID.

Set `ROOT_URL` in `BaehubNative/AppDelegate.swift`:

- Simulator: `http://localhost:3000`
- Physical device: `http://<your-lan-ip>:3000`

## Android

Project location:

- `mobile/android/BaehubNative`

Open in Android Studio and sync Gradle.

Set `ROOT_URL` in:

- `app/src/main/java/com/baehub/nativeapp/MainActivity.kt`
- `app/src/main/java/com/baehub/nativeapp/App.kt`

Use:

- Emulator: `http://10.0.2.2:3000`
- Physical device: `http://<your-lan-ip>:3000`
