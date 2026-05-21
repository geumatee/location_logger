import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:location_logger/features/location_tracking/domain/entities/location_sample.dart';
import 'package:location_logger/features/location_tracking/domain/models/tracking_bootstrap_snapshot.dart';
import 'package:location_logger/features/location_tracking/domain/models/tracking_failure.dart';
import 'package:location_logger/features/location_tracking/domain/models/tracking_permission_state.dart';
import 'package:location_logger/features/location_tracking/domain/models/tracking_settings.dart';
import 'package:location_logger/features/location_tracking/domain/models/tracking_start_result.dart';
import 'package:location_logger/features/location_tracking/domain/repositories/location_repository.dart';

part 'location_event.dart';
part 'location_state.dart';

/// BLoC that coordinates bootstrap, permissions, and dashboard state updates.
class LocationBloc extends Bloc<LocationEvent, LocationState> {
  /// Guidance shown when background access must be manually restored.
  static const String backgroundPermissionMessage =
      'Allow all the time location access to enable background tracking.';

  /// Creates the location tracking BLoC.
  LocationBloc(this._repository) : super(const LocationState.initial()) {
    on<LocationAppBootstrapped>(_onBootstrapped);
    on<LocationStatusRefreshRequested>(_onStatusRefreshRequested);
    on<LocationStartRequested>(_onStartRequested);
    on<LocationStopRequested>(_onStopRequested);
    on<BackgroundTrackingToggled>(_onBackgroundTrackingToggled);
    on<SampleIntervalChanged>(_onSampleIntervalChanged);
    on<DistanceFilterChanged>(_onDistanceFilterChanged);
    on<OpenAppSettingsRequested>(_onOpenAppSettingsRequested);
    on<OpenLocationSettingsRequested>(_onOpenLocationSettingsRequested);
    on<_LocationSampleReceived>(_onLocationSampleReceived);
    on<_TrackingFailureReceived>(_onTrackingFailureReceived);
  }

  final LocationRepository _repository;

  StreamSubscription<LocationSample>? _liveUpdatesSubscription;
  StreamSubscription<TrackingFailure>? _liveFailuresSubscription;

  Future<void> _onBootstrapped(
    LocationAppBootstrapped event,
    Emitter<LocationState> emit,
  ) async {
    emit(_buildState(isLoading: true, clearErrorMessage: true));

    _ensureRepositorySubscriptions();

    final snapshot = await _repository.bootstrap();
    final trackingEnabled = _trackingEnabledForSnapshot(snapshot);
    // Persisted failures are only shown when bootstrap does not immediately
    // return to a trackable state.
    final bootstrapErrorMessage =
        !trackingEnabled ? snapshot.persistedFailure?.message : null;

    emit(
      _buildState(
        isLoading: false,
        hasLoaded: true,
        trackingEnabled: trackingEnabled,
        backgroundEnabled: snapshot.settings.backgroundEnabled,
        sampleIntervalSeconds: snapshot.settings.sampleIntervalSeconds,
        distanceFilterMeters: snapshot.settings.distanceFilterMeters,
        permissionState: snapshot.permissionState,
        currentSample: snapshot.lastKnownSample,
        recentSamples: snapshot.recentSamples,
        errorMessage: bootstrapErrorMessage,
        clearErrorMessage: bootstrapErrorMessage == null,
      ),
    );

    if (!snapshot.settings.trackingEnabled) {
      return;
    }

    final result = await _repository.startTracking(
      settings: snapshot.settings,
      requestPermissions: false,
    );

    if (await _restartForegroundTrackingAfterBackgroundDowngradeIfNeeded(
      emit,
      result: result,
      requestedSettings: snapshot.settings,
    )) {
      return;
    }

    if (await _handleBackgroundPermissionStartFailureIfNeeded(
      emit,
      result: result,
      requestedBackgroundTracking: snapshot.settings.backgroundEnabled,
    )) {
      return;
    }

    emit(
      _buildState(
        trackingEnabled: result.didStart,
        backgroundEnabled: snapshot.settings.backgroundEnabled,
        permissionState: result.permissionState,
        errorMessage: result.errorMessage,
        clearErrorMessage: result.errorMessage == null,
      ),
    );
  }

  Future<void> _onStatusRefreshRequested(
    LocationStatusRefreshRequested event,
    Emitter<LocationState> emit,
  ) async {
    final wasTrackingEnabled = state.trackingEnabled;
    final snapshot = await _repository.bootstrap();
    final trackingEnabled = _trackingEnabledForSnapshot(snapshot);
    final refreshErrorMessage =
        !trackingEnabled ? snapshot.persistedFailure?.message : null;

    emit(
      _buildState(
        hasLoaded: true,
        trackingEnabled: trackingEnabled,
        backgroundEnabled: snapshot.settings.backgroundEnabled,
        sampleIntervalSeconds: snapshot.settings.sampleIntervalSeconds,
        distanceFilterMeters: snapshot.settings.distanceFilterMeters,
        permissionState: snapshot.permissionState,
        currentSample: snapshot.lastKnownSample ?? state.currentSample,
        recentSamples: snapshot.recentSamples,
        errorMessage: refreshErrorMessage,
        clearErrorMessage: refreshErrorMessage == null,
      ),
    );

    final shouldRehydrateTracking = snapshot.settings.trackingEnabled &&
        (snapshot.didDowngradeBackgroundPreference ||
            !snapshot.permissionState.satisfiesRequirement(
              backgroundEnabled: snapshot.settings.backgroundEnabled,
            ) ||
            !wasTrackingEnabled);
    if (!shouldRehydrateTracking) {
      return;
    }

    final result = await _repository.startTracking(
      settings: snapshot.settings.copyWith(trackingEnabled: true),
      requestPermissions: false,
    );

    if (await _restartForegroundTrackingAfterBackgroundDowngradeIfNeeded(
      emit,
      result: result,
      requestedSettings: snapshot.settings.copyWith(trackingEnabled: true),
    )) {
      return;
    }

    emit(
      _buildState(
        trackingEnabled: result.didStart,
        backgroundEnabled: snapshot.settings.backgroundEnabled,
        permissionState: result.permissionState,
        errorMessage: result.errorMessage,
        clearErrorMessage: result.errorMessage == null,
      ),
    );
  }

  Future<void> _onStartRequested(
    LocationStartRequested event,
    Emitter<LocationState> emit,
  ) async {
    emit(_buildState(isLoading: true, clearErrorMessage: true));

    final settings = TrackingSettings(
      trackingEnabled: true,
      backgroundEnabled: state.backgroundEnabled,
      sampleIntervalSeconds: state.sampleIntervalSeconds,
      distanceFilterMeters: state.distanceFilterMeters,
    );

    final result = await _repository.startTracking(settings: settings);

    if (await _restartForegroundTrackingAfterBackgroundDowngradeIfNeeded(
      emit,
      result: result,
      requestedSettings: settings,
    )) {
      return;
    }

    if (await _handleBackgroundPermissionStartFailureIfNeeded(
      emit,
      result: result,
      requestedBackgroundTracking: settings.backgroundEnabled,
    )) {
      return;
    }

    emit(
      _buildState(
        isLoading: false,
        trackingEnabled: result.didStart,
        backgroundEnabled: settings.backgroundEnabled,
        permissionState: result.permissionState,
        errorMessage: result.errorMessage,
        clearErrorMessage: result.errorMessage == null,
      ),
    );
  }

  Future<void> _onStopRequested(
    LocationStopRequested event,
    Emitter<LocationState> emit,
  ) async {
    emit(_buildState(isLoading: true, clearErrorMessage: true));
    await _repository.stopTracking();
    emit(
      _buildState(
        isLoading: false,
        trackingEnabled: false,
        clearErrorMessage: true,
      ),
    );
  }

  Future<void> _onBackgroundTrackingToggled(
    BackgroundTrackingToggled event,
    Emitter<LocationState> emit,
  ) async {
    if (event.enabled) {
      emit(_buildState(isLoading: true, clearErrorMessage: true));

      final permissionState = await _repository.ensurePermission(
        backgroundEnabled: true,
        requestIfNeeded: true,
      );

      if (!permissionState.satisfiesRequirement(backgroundEnabled: true)) {
        if (!permissionState.locksBackgroundToggle) {
          await _persistSettingsWithoutRestart(
            emit,
            backgroundEnabled: true,
            permissionStateOverride: permissionState,
          );
          return;
        }

        await _emitBackgroundPermissionLockedState(
          emit,
          permissionState: permissionState,
          trackingEnabled: state.trackingEnabled,
        );
        return;
      }

      await _persistSettingsAndRestartIfNeeded(
        emit,
        backgroundEnabled: true,
        permissionStateOverride: permissionState,
      );
      return;
    }

    await _persistSettingsAndRestartIfNeeded(
      emit,
      backgroundEnabled: false,
    );
  }

  Future<void> _onSampleIntervalChanged(
    SampleIntervalChanged event,
    Emitter<LocationState> emit,
  ) async {
    await _persistSettingsAndRestartIfNeeded(
      emit,
      sampleIntervalSeconds: event.seconds,
    );
  }

  Future<void> _onDistanceFilterChanged(
    DistanceFilterChanged event,
    Emitter<LocationState> emit,
  ) async {
    await _persistSettingsAndRestartIfNeeded(
      emit,
      distanceFilterMeters: event.meters,
    );
  }

  Future<void> _onOpenAppSettingsRequested(
    OpenAppSettingsRequested event,
    Emitter<LocationState> emit,
  ) async {
    await _repository.openAppSettings();
  }

  Future<void> _onOpenLocationSettingsRequested(
    OpenLocationSettingsRequested event,
    Emitter<LocationState> emit,
  ) async {
    await _repository.openLocationSettings();
  }

  void _onLocationSampleReceived(
    _LocationSampleReceived event,
    Emitter<LocationState> emit,
  ) {
    emit(
      _buildState(
        currentSample: event.sample,
        recentSamples: _mergeRecentSamples(
          current: state.recentSamples,
          incoming: event.sample,
        ),
      ),
    );
  }

  Future<void> _onTrackingFailureReceived(
    _TrackingFailureReceived event,
    Emitter<LocationState> emit,
  ) async {
    if (event.failure.kind == TrackingFailureKind.backgroundPermissionDenied) {
      if (await _restartForegroundTrackingAfterBackgroundDowngradeIfNeeded(
        emit,
        result: TrackingStartResult.failure(
          permissionState: event.failure.permissionState,
          message: event.failure.message,
        ),
        requestedSettings: TrackingSettings(
          trackingEnabled: true,
          backgroundEnabled: true,
          sampleIntervalSeconds: state.sampleIntervalSeconds,
          distanceFilterMeters: state.distanceFilterMeters,
        ),
      )) {
        return;
      }

      await _emitBackgroundPermissionLockedState(
        emit,
        permissionState: event.failure.permissionState,
        trackingEnabled: false,
        errorMessage: event.failure.message,
        clearErrorMessage: false,
      );
      return;
    }

    emit(
      _buildState(
        isLoading: false,
        trackingEnabled: false,
        permissionState: event.failure.permissionState,
        errorMessage: event.failure.message,
        clearErrorMessage: false,
      ),
    );
  }

  Future<void> _persistSettingsWithoutRestart(
    Emitter<LocationState> emit, {
    bool? backgroundEnabled,
    int? sampleIntervalSeconds,
    int? distanceFilterMeters,
    TrackingPermissionState? permissionStateOverride,
  }) async {
    emit(
      _buildState(
        isLoading: true,
        backgroundEnabled: backgroundEnabled,
        sampleIntervalSeconds: sampleIntervalSeconds,
        distanceFilterMeters: distanceFilterMeters,
        permissionState: permissionStateOverride,
        clearErrorMessage: true,
      ),
    );

    final settings = await _repository.updateTrackingSettings(
      backgroundEnabled: backgroundEnabled,
      sampleIntervalSeconds: sampleIntervalSeconds,
      distanceFilterMeters: distanceFilterMeters,
    );

    emit(
      _buildState(
        isLoading: false,
        backgroundEnabled: settings.backgroundEnabled,
        sampleIntervalSeconds: settings.sampleIntervalSeconds,
        distanceFilterMeters: settings.distanceFilterMeters,
        permissionState: permissionStateOverride,
        clearErrorMessage: true,
      ),
    );
  }

  Future<void> _persistSettingsAndRestartIfNeeded(
    Emitter<LocationState> emit, {
    bool? backgroundEnabled,
    int? sampleIntervalSeconds,
    int? distanceFilterMeters,
    TrackingPermissionState? permissionStateOverride,
    bool requestPermissionsOnRestart = false,
  }) async {
    final trackingWasEnabled = state.trackingEnabled;

    emit(
      _buildState(
        isLoading: true,
        backgroundEnabled: backgroundEnabled,
        sampleIntervalSeconds: sampleIntervalSeconds,
        distanceFilterMeters: distanceFilterMeters,
        permissionState: permissionStateOverride,
        clearErrorMessage: true,
      ),
    );

    final settings = await _repository.updateTrackingSettings(
      backgroundEnabled: backgroundEnabled,
      sampleIntervalSeconds: sampleIntervalSeconds,
      distanceFilterMeters: distanceFilterMeters,
    );

    if (!trackingWasEnabled) {
      emit(
        _buildState(
          isLoading: false,
          backgroundEnabled: settings.backgroundEnabled,
          sampleIntervalSeconds: settings.sampleIntervalSeconds,
          distanceFilterMeters: settings.distanceFilterMeters,
          permissionState: permissionStateOverride,
        ),
      );
      return;
    }

    // Apply live setting changes immediately by restarting the active runtime.
    await _repository.stopTracking();
    final result = await _repository.startTracking(
      settings: settings.copyWith(trackingEnabled: true),
      requestPermissions: requestPermissionsOnRestart,
    );

    if (await _restartForegroundTrackingAfterBackgroundDowngradeIfNeeded(
      emit,
      result: result,
      requestedSettings: settings.copyWith(trackingEnabled: true),
    )) {
      return;
    }

    if (await _handleBackgroundPermissionStartFailureIfNeeded(
      emit,
      result: result,
      requestedBackgroundTracking: settings.backgroundEnabled,
    )) {
      return;
    }

    emit(
      _buildState(
        isLoading: false,
        trackingEnabled: result.didStart,
        backgroundEnabled: settings.backgroundEnabled,
        sampleIntervalSeconds: settings.sampleIntervalSeconds,
        distanceFilterMeters: settings.distanceFilterMeters,
        permissionState: result.permissionState,
        errorMessage: result.errorMessage,
        clearErrorMessage: result.errorMessage == null,
      ),
    );
  }

  void _ensureRepositorySubscriptions() {
    _liveUpdatesSubscription ??= _repository.liveUpdates.listen(
      (sample) => add(_LocationSampleReceived(sample)),
    );
    _liveFailuresSubscription ??= _repository.liveFailures.listen(
      (failure) => add(_TrackingFailureReceived(failure)),
    );
  }

  LocationState _buildState({
    bool? hasLoaded,
    bool? isLoading,
    bool? trackingEnabled,
    bool? backgroundEnabled,
    int? sampleIntervalSeconds,
    int? distanceFilterMeters,
    TrackingPermissionState? permissionState,
    LocationSample? currentSample,
    List<LocationSample>? recentSamples,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    final resolvedTrackingEnabled = trackingEnabled ?? state.trackingEnabled;
    final resolvedBackgroundEnabled =
        backgroundEnabled ?? state.backgroundEnabled;
    final resolvedPermissionState = permissionState ?? state.permissionState;
    final derivation = _deriveTrackingUi(
      trackingEnabled: resolvedTrackingEnabled,
      backgroundRequested: resolvedBackgroundEnabled,
      permissionState: resolvedPermissionState,
    );

    return state.copyWith(
      hasLoaded: hasLoaded,
      isLoading: isLoading,
      trackingEnabled: trackingEnabled,
      backgroundEnabled: backgroundEnabled,
      effectiveBackgroundEnabled: derivation.effectiveBackgroundEnabled,
      sampleIntervalSeconds: sampleIntervalSeconds,
      distanceFilterMeters: distanceFilterMeters,
      permissionState: permissionState,
      currentSample: currentSample,
      recentSamples: recentSamples,
      errorMessage: errorMessage,
      clearErrorMessage: clearErrorMessage,
      isBackgroundToggleLocked: derivation.isBackgroundToggleLocked,
      backgroundTrackingMessage: derivation.backgroundTrackingMessage,
      clearBackgroundTrackingMessage:
          derivation.backgroundTrackingMessage == null,
    );
  }

  _TrackingUiDerivation _deriveTrackingUi({
    required bool trackingEnabled,
    required bool backgroundRequested,
    required TrackingPermissionState permissionState,
  }) {
    final backgroundTrackingMessage = _backgroundTrackingMessage(
      permissionState: permissionState,
      backgroundRequested: backgroundRequested,
    );

    return _TrackingUiDerivation(
      effectiveBackgroundEnabled: _effectiveBackgroundEnabled(
        trackingEnabled: trackingEnabled,
        backgroundRequested: backgroundRequested,
        permissionState: permissionState,
      ),
      isBackgroundToggleLocked:
          _shouldLockBackgroundToggleForPermissionState(permissionState),
      backgroundTrackingMessage: backgroundTrackingMessage,
    );
  }

  bool _shouldLockBackgroundToggleForPermissionState(
    TrackingPermissionState permissionState,
  ) {
    return permissionState.locksBackgroundToggle;
  }

  bool _shouldLockBackgroundToggleForStartFailure({
    required TrackingStartResult result,
    required bool requestedBackgroundTracking,
  }) {
    return requestedBackgroundTracking &&
        !result.didStart &&
        _shouldLockBackgroundToggleForPermissionState(result.permissionState) &&
        !result.permissionState.satisfiesRequirement(backgroundEnabled: false);
  }

  Future<bool> _restartForegroundTrackingAfterBackgroundDowngradeIfNeeded(
    Emitter<LocationState> emit, {
    required TrackingStartResult result,
    required TrackingSettings requestedSettings,
  }) async {
    final canDowngradeToForeground = requestedSettings.backgroundEnabled &&
        !result.didStart &&
        result.permissionState.locksBackgroundToggle &&
        result.permissionState.satisfiesRequirement(backgroundEnabled: false);
    if (!canDowngradeToForeground) {
      return false;
    }

    // When "Always" access drops back to foreground-only access, keep the
    // session alive by clearing the background request and restarting simply.
    final downgradedSettings =
        await _repository.updateTrackingSettings(backgroundEnabled: false);
    final downgradedResult = await _repository.startTracking(
      settings: downgradedSettings.copyWith(trackingEnabled: true),
      requestPermissions: false,
    );

    if (!downgradedResult.didStart) {
      await _emitBackgroundPermissionLockedState(
        emit,
        permissionState: downgradedResult.permissionState,
        trackingEnabled: false,
        errorMessage: downgradedResult.errorMessage,
        clearErrorMessage: downgradedResult.errorMessage == null,
      );
      return true;
    }

    emit(
      _buildState(
        isLoading: false,
        trackingEnabled: true,
        backgroundEnabled: downgradedSettings.backgroundEnabled,
        sampleIntervalSeconds: downgradedSettings.sampleIntervalSeconds,
        distanceFilterMeters: downgradedSettings.distanceFilterMeters,
        permissionState: downgradedResult.permissionState,
        clearErrorMessage: true,
      ),
    );
    return true;
  }

  Future<bool> _handleBackgroundPermissionStartFailureIfNeeded(
    Emitter<LocationState> emit, {
    required TrackingStartResult result,
    required bool requestedBackgroundTracking,
  }) async {
    if (!_shouldLockBackgroundToggleForStartFailure(
      result: result,
      requestedBackgroundTracking: requestedBackgroundTracking,
    )) {
      return false;
    }

    await _emitBackgroundPermissionLockedState(
      emit,
      permissionState: result.permissionState,
      trackingEnabled: false,
    );
    return true;
  }

  Future<void> _emitBackgroundPermissionLockedState(
    Emitter<LocationState> emit, {
    required TrackingPermissionState permissionState,
    required bool trackingEnabled,
    String? errorMessage,
    bool clearErrorMessage = true,
  }) async {
    await _repository.updateTrackingSettings(backgroundEnabled: false);

    emit(
      _buildState(
        isLoading: false,
        trackingEnabled: trackingEnabled,
        backgroundEnabled: false,
        permissionState: permissionState,
        errorMessage: errorMessage,
        clearErrorMessage: clearErrorMessage,
      ),
    );
  }

  bool _trackingEnabledForSnapshot(TrackingBootstrapSnapshot snapshot) {
    return snapshot.settings.trackingEnabled &&
        snapshot.permissionState.satisfiesRequirement(
          backgroundEnabled: snapshot.settings.backgroundEnabled,
        );
  }

  bool _effectiveBackgroundEnabled({
    required bool trackingEnabled,
    required bool backgroundRequested,
    required TrackingPermissionState permissionState,
  }) {
    return trackingEnabled &&
        permissionState.effectiveBackgroundEnabled(
          backgroundRequested: backgroundRequested,
        );
  }

  String? _backgroundTrackingMessage({
    required TrackingPermissionState permissionState,
    required bool backgroundRequested,
  }) {
    if (permissionState == TrackingPermissionState.deniedForever) {
      return 'Location access is permanently denied. Open app settings to continue.';
    }

    if (permissionState.locksBackgroundToggle) {
      return backgroundPermissionMessage;
    }

    if (!backgroundRequested) {
      return null;
    }

    if (permissionState == TrackingPermissionState.serviceDisabled) {
      return 'Background tracking is requested, but location services are currently turned off.';
    }

    if (permissionState == TrackingPermissionState.unknown) {
      return 'Background tracking is requested, but the current location access status is not available yet.';
    }

    return null;
  }

  List<LocationSample> _mergeRecentSamples({
    required List<LocationSample> current,
    required LocationSample incoming,
  }) {
    final merged = <LocationSample>[incoming];
    final incomingKey = _sampleKey(incoming);

    for (final sample in current) {
      if (_sampleKey(sample) == incomingKey) {
        continue;
      }
      merged.add(sample);
      if (merged.length == 5) {
        break;
      }
    }

    return List<LocationSample>.unmodifiable(merged);
  }

  String _sampleKey(LocationSample sample) {
    return '${sample.capturedAtUtc.microsecondsSinceEpoch}:${sample.latitude}:${sample.longitude}';
  }

  @override
  Future<void> close() async {
    await _liveUpdatesSubscription?.cancel();
    await _liveFailuresSubscription?.cancel();
    return super.close();
  }
}

class _TrackingUiDerivation {
  const _TrackingUiDerivation({
    required this.effectiveBackgroundEnabled,
    required this.isBackgroundToggleLocked,
    required this.backgroundTrackingMessage,
  });

  final bool effectiveBackgroundEnabled;
  final bool isBackgroundToggleLocked;
  final String? backgroundTrackingMessage;
}
