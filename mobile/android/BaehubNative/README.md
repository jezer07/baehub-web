# Baehub Native Android (Starter)

## Requirements

- Android Studio Iguana+ (or current)
- Android SDK 35
- JDK 17

## Configure base URL

Edit both files and set `ROOT_URL`:

- `app/src/main/java/com/baehub/nativeapp/MainActivity.kt`
- `app/src/main/java/com/baehub/nativeapp/App.kt`

Values:

- Emulator: `http://10.0.2.2:3000`
- Device: `http://<your-lan-ip>:3000`

## Run

1. Start Rails: `bin/rails server -b 0.0.0.0 -p 3000`
2. Open this folder in Android Studio.
3. Sync Gradle.
4. Run app on emulator/device.
