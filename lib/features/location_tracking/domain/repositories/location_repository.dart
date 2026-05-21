import 'package:location_logger/features/location_tracking/domain/entities/location_sample.dart';
import 'package:location_logger/features/location_tracking/domain/models/tracking_bootstrap_snapshot.dart';
import 'package:location_logger/features/location_tracking/domain/models/tracking_failure.dart';
import 'package:location_logger/features/location_tracking/domain/models/tracking_permission_state.dart';
import 'package:location_logger/features/location_tracking/domain/models/tracking_settings.dart';
import 'package:location_logger/features/location_tracking/domain/models/tracking_start_result.dart';

/// Contract for reading and controlling location tracking state.
abstract class LocationRepository {
  /// Live stream of persisted samples emitted by the active runtime.
  Stream<LocationSample> get liveUpdates;

  /// Live stream of structured failures emitted by the active runtime.
  Stream<TrackingFailure> get liveFailures;

  /// Restores the most recent persisted state for app startup.
  Future<TrackingBootstrapSnapshot> bootstrap({int recentLimit = 5});

  /// Checks or requests permissions needed for the requested tracking mode.
  Future<TrackingPermissionState> ensurePermission({
    required bool backgroundEnabled,
    bool requestIfNeeded = false,
  });

  /// Starts tracking with the provided settings.
  Future<TrackingStartResult> startTracking({
    required TrackingSettings settings,
    bool requestPermissions = true,
  });

  /// Stops any active tracking session.
  Future<void> stopTracking();

  /// Updates the persisted tracking settings.
  Future<TrackingSettings> updateTrackingSettings({
    bool? backgroundEnabled,
    int? sampleIntervalSeconds,
    int? distanceFilterMeters,
  });

  /// Opens the operating system's app settings screen.
  Future<void> openAppSettings();

  /// Opens the operating system's location settings screen.
  Future<void> openLocationSettings();

  /// Releases subscriptions, controllers, and other owned resources.
  Future<void> dispose();
}
