# Location Logger

Location Logger is a Flutter demo app that records device latitude and longitude in the foreground, background, and, on Android, after the app is removed from recent apps.

## Features

- Foreground location tracking with permission handling
- Android foreground-service tracking with a persistent notification
- iOS background tracking with Core Location background mode
- SQLite-backed location history
- Toggle to enable or disable background tracking for testing
- Foreground fallback when all-the-time access drops back to foreground-only
- Dashboard that shows the current or last known sample and the five most recent logs

## Stack

- Flutter 3.29+
- Dart 3.5+
- `flutter_bloc`
- `get_it`
- `geolocator`
- `flutter_background_service`
- `sqflite`
- `shared_preferences` via `SharedPreferencesAsync`
- `flutter_local_notifications`

## Engineering Guide

For engineer-facing documentation, see [docs/architecture.md](docs/architecture.md).

It covers:

- file and folder structure
- startup, tracking, and failure handling flow
- data flow between UI, BLoC, repository, storage, and the Android background service
- where to change behavior when working on UI, runtime logic, or persistence

## Project Structure

- `lib/core`: dependency injection, theme, formatting helpers
- `lib/features/location_tracking/domain`: entities, repository contracts, workflow models
- `lib/features/location_tracking/data`: persistence, platform services, repository implementation
- `lib/features/location_tracking/presentation`: BLoC, widgets, dashboard page
- `test/features/location_tracking`: repository, storage, runtime-policy, bloc, and widget coverage

The tracking feature is intentionally map-ready: the repository and `LocationSample` entity can support a future map screen without schema changes.

## Android Notes

Android uses a foreground service plus a persistent notification to keep location tracking alive while the app is backgrounded. The service writes every accepted location update into SQLite and mirrors the latest sample into preferences so the dashboard can restore quickly on relaunch.

Recent-apps removal support depends on normal Android foreground-service behavior. The service is configured with `stopWithTask="false"`, but users can still explicitly stop foreground services from system controls.

While tracking is active, the app also watches the device-wide Location toggle. Turning location services off should stop the session, persist the inline error, and clear the foreground-service notification instead of leaving a stale service running.

If background access drops back to foreground-only access while the dashboard is active, the app clears the background request, locks the toggle, and restarts in foreground mode instead of leaving the session stopped.

## iOS Notes

iOS supports foreground and background tracking with Core Location background mode enabled. If the user force-quits the app, continuous interval-style tracking is not guaranteed to continue; the app restores persisted history and the last known sample when relaunched.

When the app is active and `Always` access falls back to `When In Use`, the dashboard clears the background request, locks the toggle, and keeps foreground-only tracking running.

## Setup

1. Install Flutter 3.29 or later.
2. Run `flutter pub get`.
3. Open an Android emulator/device or an iOS simulator/device.
4. Run `flutter run`.

## Manual Verification

### Android

1. Grant foreground and background location access.
2. Start tracking and confirm the dashboard updates.
3. Enable background tracking and confirm the persistent notification appears.
4. Send the app to background and verify new samples keep appearing.
5. Remove the app from recents and verify the notification and logs continue updating.
6. While the app is still removed from recents, induce a runtime failure such as disabling location services and confirm the foreground service stops and the persistent notification disappears.
7. Relaunch and confirm the dashboard shows tracking stopped, preserves the latest sample and recent history, and surfaces the persisted inline error.
8. Start foreground tracking, then try enabling background mode without `Always` access.
9. Confirm the app keeps foreground tracking alive when possible, clears the saved background request only for the true permission downgrade case, shows the background permission guidance, and locks the switch until `Always` is restored.
10. Re-enable background mode, then temporarily disable location services or otherwise force a transient unavailable state.
11. Confirm tracking stops, the background switch stays on, the dashboard shows foreground-only effective mode, and the transient guidance appears without erasing the saved background request.
12. While the dashboard is open and background tracking is active, change location access from `Always` to foreground-only access and confirm the app keeps tracking alive by downgrading to foreground mode.

### iOS

1. Grant When In Use and Always location access.
2. Start tracking and confirm the dashboard updates.
3. Enable background tracking and send the app to the background.
4. Return to the app and confirm the last known location and history remain available.
5. While tracking is active, switch location access back to When In Use and reopen the app.
6. Confirm the saved background request is cleared, the dashboard falls back to foreground-only mode, the switch locks, and the last known sample remains visible.
7. Re-enable `Always`, turn background tracking back on, then temporarily disable location services or otherwise force an unavailable state.
8. Confirm the switch stays on, the dashboard shows foreground-only effective mode, and the transient guidance appears without erasing the saved background request.
9. Trigger a runtime interruption and confirm the inline error appears while the history remains intact.
10. Force-quit the app and confirm the documented limitation is understood: continuous interval-style tracking is not expected to continue after an explicit force-quit.
11. While the dashboard is open and background tracking is active, change location access from `Always` to `When In Use` and confirm the app keeps tracking alive by downgrading to foreground mode.

## Future Map Extension

To add a map later, build a second presentation screen that consumes `LocationRepository` history or the current `LocationSample` from the BLoC. The storage schema already keeps timestamped coordinates in a format suitable for polylines or marker history.
