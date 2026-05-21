part of 'location_bloc.dart';

/// Immutable dashboard state rendered by the location tracking feature.
class LocationState extends Equatable {
  /// Creates a location state snapshot.
  const LocationState({
    required this.hasLoaded,
    required this.isLoading,
    required this.trackingEnabled,
    required this.backgroundEnabled,
    required this.effectiveBackgroundEnabled,
    required this.sampleIntervalSeconds,
    required this.distanceFilterMeters,
    required this.permissionState,
    required this.recentSamples,
    required this.isBackgroundToggleLocked,
    this.currentSample,
    this.errorMessage,
    this.backgroundTrackingMessage,
  });

  /// Default state used before bootstrap completes.
  const LocationState.initial()
      : hasLoaded = false,
        isLoading = false,
        trackingEnabled = false,
        backgroundEnabled = false,
        effectiveBackgroundEnabled = false,
        sampleIntervalSeconds = 60,
        distanceFilterMeters = 10,
        permissionState = TrackingPermissionState.unknown,
        recentSamples = const <LocationSample>[],
        isBackgroundToggleLocked = false,
        currentSample = null,
        errorMessage = null,
        backgroundTrackingMessage = null;

  /// Whether bootstrap or refresh has completed at least once.
  final bool hasLoaded;

  /// Whether the feature is currently performing async work.
  final bool isLoading;

  /// Whether tracking is currently active.
  final bool trackingEnabled;

  /// Whether the user requested background-capable tracking.
  final bool backgroundEnabled;

  /// Whether background tracking is effectively available right now.
  final bool effectiveBackgroundEnabled;

  /// Selected sample interval in seconds.
  final int sampleIntervalSeconds;

  /// Selected distance filter in meters.
  final int distanceFilterMeters;

  /// Current normalized permission state.
  final TrackingPermissionState permissionState;

  /// Recent persisted samples shown in the dashboard history card.
  final List<LocationSample> recentSamples;

  /// Whether the background toggle should be disabled in the UI.
  final bool isBackgroundToggleLocked;

  /// Current or last known sample displayed by the dashboard.
  final LocationSample? currentSample;

  /// Optional error message shown inline when tracking stops or degrades.
  final String? errorMessage;

  /// Optional message explaining current background tracking limitations.
  final String? backgroundTrackingMessage;

  /// Whether the Start button should be enabled.
  bool get canStart => !isLoading && !trackingEnabled;

  /// Whether the Stop button should be enabled.
  bool get canStop => !isLoading && trackingEnabled;

  /// Returns a copy of the state with the provided field overrides.
  LocationState copyWith({
    bool? hasLoaded,
    bool? isLoading,
    bool? trackingEnabled,
    bool? backgroundEnabled,
    bool? effectiveBackgroundEnabled,
    int? sampleIntervalSeconds,
    int? distanceFilterMeters,
    TrackingPermissionState? permissionState,
    List<LocationSample>? recentSamples,
    bool? isBackgroundToggleLocked,
    LocationSample? currentSample,
    String? errorMessage,
    String? backgroundTrackingMessage,
    bool clearErrorMessage = false,
    bool clearBackgroundTrackingMessage = false,
  }) {
    return LocationState(
      hasLoaded: hasLoaded ?? this.hasLoaded,
      isLoading: isLoading ?? this.isLoading,
      trackingEnabled: trackingEnabled ?? this.trackingEnabled,
      backgroundEnabled: backgroundEnabled ?? this.backgroundEnabled,
      effectiveBackgroundEnabled:
          effectiveBackgroundEnabled ?? this.effectiveBackgroundEnabled,
      sampleIntervalSeconds:
          sampleIntervalSeconds ?? this.sampleIntervalSeconds,
      distanceFilterMeters: distanceFilterMeters ?? this.distanceFilterMeters,
      permissionState: permissionState ?? this.permissionState,
      recentSamples: recentSamples ?? this.recentSamples,
      isBackgroundToggleLocked:
          isBackgroundToggleLocked ?? this.isBackgroundToggleLocked,
      currentSample: currentSample ?? this.currentSample,
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      backgroundTrackingMessage: clearBackgroundTrackingMessage
          ? null
          : (backgroundTrackingMessage ?? this.backgroundTrackingMessage),
    );
  }

  @override
  List<Object?> get props => <Object?>[
        hasLoaded,
        isLoading,
        trackingEnabled,
        backgroundEnabled,
        effectiveBackgroundEnabled,
        sampleIntervalSeconds,
        distanceFilterMeters,
        permissionState,
        recentSamples,
        isBackgroundToggleLocked,
        currentSample,
        errorMessage,
        backgroundTrackingMessage,
      ];
}
