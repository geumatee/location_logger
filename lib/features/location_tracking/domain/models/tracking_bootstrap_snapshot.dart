import 'package:equatable/equatable.dart';
import 'package:location_logger/features/location_tracking/domain/entities/location_sample.dart';
import 'package:location_logger/features/location_tracking/domain/models/tracking_failure.dart';
import 'package:location_logger/features/location_tracking/domain/models/tracking_permission_state.dart';
import 'package:location_logger/features/location_tracking/domain/models/tracking_settings.dart';

/// Snapshot returned when the app reconstructs tracking state on launch.
class TrackingBootstrapSnapshot extends Equatable {
  /// Creates a bootstrap snapshot.
  const TrackingBootstrapSnapshot({
    required this.settings,
    required this.permissionState,
    required this.recentSamples,
    this.didDowngradeBackgroundPreference = false,
    this.lastKnownSample,
    this.persistedFailure,
  });

  /// Persisted tracking settings after any permission-based normalization.
  final TrackingSettings settings;

  /// Current permission state observed during bootstrap.
  final TrackingPermissionState permissionState;

  /// Most recent persisted samples used to seed the dashboard.
  final List<LocationSample> recentSamples;

  /// Whether bootstrap had to clear a no-longer-valid background preference.
  final bool didDowngradeBackgroundPreference;

  /// Last known sample restored from storage for immediate UI hydration.
  final LocationSample? lastKnownSample;

  /// Persisted failure that should be surfaced when tracking is stopped.
  final TrackingFailure? persistedFailure;

  @override
  List<Object?> get props => <Object?>[
        settings,
        permissionState,
        recentSamples,
        didDowngradeBackgroundPreference,
        lastKnownSample,
        persistedFailure,
      ];
}
