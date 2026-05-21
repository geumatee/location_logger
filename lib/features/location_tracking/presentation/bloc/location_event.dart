part of 'location_bloc.dart';

/// Base class for all dashboard interactions and repository updates.
sealed class LocationEvent extends Equatable {
  /// Creates a location event.
  const LocationEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// Triggers the initial bootstrap flow when the app launches.
class LocationAppBootstrapped extends LocationEvent {
  /// Creates an app bootstrap event.
  const LocationAppBootstrapped();
}

/// Refreshes persisted state after the app returns to the foreground.
class LocationStatusRefreshRequested extends LocationEvent {
  /// Creates a status refresh event.
  const LocationStatusRefreshRequested();
}

/// Starts tracking with the currently selected settings.
class LocationStartRequested extends LocationEvent {
  /// Creates a start tracking event.
  const LocationStartRequested();
}

/// Stops the current tracking session.
class LocationStopRequested extends LocationEvent {
  /// Creates a stop tracking event.
  const LocationStopRequested();
}

/// Updates the user's background tracking preference.
class BackgroundTrackingToggled extends LocationEvent {
  /// Creates a background toggle event.
  const BackgroundTrackingToggled(this.enabled);

  /// Whether background tracking should be requested.
  final bool enabled;

  @override
  List<Object?> get props => <Object?>[enabled];
}

/// Updates the preferred sample interval.
class SampleIntervalChanged extends LocationEvent {
  /// Creates a sample interval change event.
  const SampleIntervalChanged(this.seconds);

  /// New sample interval in seconds.
  final int seconds;

  @override
  List<Object?> get props => <Object?>[seconds];
}

/// Updates the preferred distance filter.
class DistanceFilterChanged extends LocationEvent {
  /// Creates a distance filter change event.
  const DistanceFilterChanged(this.meters);

  /// New distance filter in meters.
  final int meters;

  @override
  List<Object?> get props => <Object?>[meters];
}

/// Opens the operating system's app settings screen.
class OpenAppSettingsRequested extends LocationEvent {
  /// Creates an open app settings event.
  const OpenAppSettingsRequested();
}

/// Opens the operating system's location settings screen.
class OpenLocationSettingsRequested extends LocationEvent {
  /// Creates an open location settings event.
  const OpenLocationSettingsRequested();
}

class _LocationSampleReceived extends LocationEvent {
  const _LocationSampleReceived(this.sample);

  final LocationSample sample;

  @override
  List<Object?> get props => <Object?>[sample];
}

class _TrackingFailureReceived extends LocationEvent {
  const _TrackingFailureReceived(this.failure);

  final TrackingFailure failure;

  @override
  List<Object?> get props => <Object?>[failure];
}
