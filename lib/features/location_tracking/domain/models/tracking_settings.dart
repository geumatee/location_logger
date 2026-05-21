import 'package:equatable/equatable.dart';

/// Persisted runtime settings that control how tracking should behave.
class TrackingSettings extends Equatable {
  /// Creates tracking settings.
  const TrackingSettings({
    required this.trackingEnabled,
    required this.backgroundEnabled,
    required this.sampleIntervalSeconds,
    required this.distanceFilterMeters,
  });

  /// Default tracking settings used before the user changes anything.
  const TrackingSettings.initial()
      : trackingEnabled = false,
        backgroundEnabled = false,
        sampleIntervalSeconds = 60,
        distanceFilterMeters = 10;

  /// Whether tracking should currently be active.
  final bool trackingEnabled;

  /// Whether the user requested background-capable tracking.
  final bool backgroundEnabled;

  /// Desired sample interval in seconds.
  final int sampleIntervalSeconds;

  /// Desired minimum distance change between samples in meters.
  final int distanceFilterMeters;

  /// Returns a copy with updated tracking settings.
  TrackingSettings copyWith({
    bool? trackingEnabled,
    bool? backgroundEnabled,
    int? sampleIntervalSeconds,
    int? distanceFilterMeters,
  }) {
    return TrackingSettings(
      trackingEnabled: trackingEnabled ?? this.trackingEnabled,
      backgroundEnabled: backgroundEnabled ?? this.backgroundEnabled,
      sampleIntervalSeconds:
          sampleIntervalSeconds ?? this.sampleIntervalSeconds,
      distanceFilterMeters: distanceFilterMeters ?? this.distanceFilterMeters,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        trackingEnabled,
        backgroundEnabled,
        sampleIntervalSeconds,
        distanceFilterMeters,
      ];
}
