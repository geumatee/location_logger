import 'dart:async';
import 'dart:io';

import 'package:geolocator/geolocator.dart';

/// Thin wrapper around `geolocator` so platform calls are easy to stub in tests.
class DeviceLocationSource {
  /// Returns whether device-wide location services are enabled.
  Future<bool> isServiceEnabled() {
    return Geolocator.isLocationServiceEnabled();
  }

  /// Returns the current location permission granted to the app.
  Future<LocationPermission> checkPermission() {
    return Geolocator.checkPermission();
  }

  /// Requests location permission from the user when possible.
  Future<LocationPermission> requestPermission() {
    return Geolocator.requestPermission();
  }

  /// Creates the position stream that powers foreground and background logging.
  Stream<Position> positionStream({
    required bool backgroundEnabled,
    required int sampleIntervalSeconds,
    required int distanceFilterMeters,
  }) {
    final settings = _buildSettings(
      backgroundEnabled: backgroundEnabled,
      sampleIntervalSeconds: sampleIntervalSeconds,
      distanceFilterMeters: distanceFilterMeters,
    );
    return Geolocator.getPositionStream(locationSettings: settings);
  }

  /// Emits device-wide location service status changes while tracking is active.
  Stream<ServiceStatus> serviceStatusStream() {
    return Geolocator.getServiceStatusStream();
  }

  /// Opens the operating system's app settings screen.
  Future<void> openAppSettings() {
    return Geolocator.openAppSettings();
  }

  /// Opens the operating system's location settings screen.
  Future<void> openLocationSettings() {
    return Geolocator.openLocationSettings();
  }

  LocationSettings _buildSettings({
    required bool backgroundEnabled,
    required int sampleIntervalSeconds,
    required int distanceFilterMeters,
  }) {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilterMeters,
        intervalDuration: Duration(seconds: sampleIntervalSeconds),
        foregroundNotificationConfig: backgroundEnabled
            ? const ForegroundNotificationConfig(
                notificationTitle: 'Location Logger active',
                notificationText: 'Collecting background location updates.',
                enableWakeLock: true,
              )
            : null,
      );
    }

    if (Platform.isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.best,
        activityType: ActivityType.otherNavigation,
        allowBackgroundLocationUpdates: backgroundEnabled,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: backgroundEnabled,
        distanceFilter: distanceFilterMeters,
      );
    }

    return LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: distanceFilterMeters,
    );
  }
}
