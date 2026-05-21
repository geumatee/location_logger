import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:location_logger/core/utils/platform_info.dart';
import 'package:location_logger/features/location_tracking/data/services/android_background_service.dart';
import 'package:location_logger/features/location_tracking/data/services/device_location_source.dart';
import 'package:location_logger/features/location_tracking/data/services/notification_coordinator.dart';
import 'package:location_logger/features/location_tracking/data/services/tracking_runtime_policy.dart';
import 'package:location_logger/features/location_tracking/data/storage/location_database.dart';
import 'package:location_logger/features/location_tracking/data/storage/tracking_settings_store.dart';
import 'package:location_logger/features/location_tracking/domain/entities/location_sample.dart';
import 'package:location_logger/features/location_tracking/domain/models/tracking_bootstrap_snapshot.dart';
import 'package:location_logger/features/location_tracking/domain/models/tracking_failure.dart';
import 'package:location_logger/features/location_tracking/domain/models/tracking_permission_state.dart';
import 'package:location_logger/features/location_tracking/domain/models/tracking_settings.dart';
import 'package:location_logger/features/location_tracking/domain/models/tracking_start_result.dart';
import 'package:location_logger/features/location_tracking/domain/repositories/location_repository.dart';

/// Default repository that coordinates permissions, persistence, and runtime IO.
class LocationRepositoryImpl implements LocationRepository {
  /// Creates a location repository implementation.
  LocationRepositoryImpl({
    required LocationDatabase database,
    required TrackingSettingsStore settingsStore,
    required DeviceLocationSource locationSource,
    required AndroidBackgroundServiceManager backgroundService,
    required NotificationCoordinator notificationCoordinator,
    required PlatformInfo platformInfo,
  })  : _database = database,
        _settingsStore = settingsStore,
        _locationSource = locationSource,
        _backgroundService = backgroundService,
        _notificationCoordinator = notificationCoordinator,
        _platformInfo = platformInfo {
    _backgroundLiveUpdatesSubscription =
        _backgroundService.liveUpdates.listen(_publishBackgroundSample);
    _backgroundLiveFailuresSubscription =
        _backgroundService.liveFailures.listen((failure) {
      unawaited(_handleBackgroundServiceFailure(failure));
    });
  }

  final LocationDatabase _database;
  final TrackingSettingsStore _settingsStore;
  final DeviceLocationSource _locationSource;
  final AndroidBackgroundServiceManager _backgroundService;
  final NotificationCoordinator _notificationCoordinator;
  final PlatformInfo _platformInfo;

  final StreamController<LocationSample> _liveUpdatesController =
      StreamController<LocationSample>.broadcast();
  final StreamController<TrackingFailure> _liveFailuresController =
      StreamController<TrackingFailure>.broadcast();

  StreamSubscription<LocationSample>? _backgroundLiveUpdatesSubscription;
  StreamSubscription<TrackingFailure>? _backgroundLiveFailuresSubscription;
  StreamSubscription<Position>? _directTrackingSubscription;
  StreamSubscription<ServiceStatus>? _serviceStatusSubscription;
  bool _directTerminalTransitionStarted = false;
  bool _isDisposed = false;

  @override
  Stream<LocationSample> get liveUpdates => _liveUpdatesController.stream;

  @override
  Stream<TrackingFailure> get liveFailures => _liveFailuresController.stream;

  @override
  Future<TrackingBootstrapSnapshot> bootstrap({int recentLimit = 5}) async {
    final storedSettings = await _settingsStore.readSettings();
    final permissionState = await ensurePermission(
      backgroundEnabled: storedSettings.backgroundEnabled,
    );
    // Only clear the saved background request when the OS state shows the
    // preference can no longer be honored, not during transient outages.
    final normalization = await _normalizeSettingsForPermission(
      settings: storedSettings,
      permissionState: permissionState,
    );
    final settings = normalization.settings;
    final recentSamples =
        await _database.fetchRecentSamples(limit: recentLimit);
    final lastKnownSample = await _settingsStore.readLastKnownSample() ??
        (recentSamples.isNotEmpty ? recentSamples.first : null);
    final persistedFailure = await _settingsStore.readLastTrackingFailure();

    return TrackingBootstrapSnapshot(
      settings: settings,
      permissionState: permissionState,
      recentSamples: recentSamples,
      didDowngradeBackgroundPreference:
          normalization.didDowngradeBackgroundPreference,
      lastKnownSample: lastKnownSample,
      persistedFailure: persistedFailure,
    );
  }

  @override
  Future<TrackingPermissionState> ensurePermission({
    required bool backgroundEnabled,
    bool requestIfNeeded = false,
  }) async {
    final servicesEnabled = await _locationSource.isServiceEnabled();
    if (!servicesEnabled) {
      return TrackingPermissionState.serviceDisabled;
    }

    var permission = await _locationSource.checkPermission();
    var permissionState = mapTrackingPermission(
      permission: permission,
      servicesEnabled: servicesEnabled,
    );

    if (requestIfNeeded &&
        !permissionState.satisfiesRequirement(
          backgroundEnabled: backgroundEnabled,
        ) &&
        permission != LocationPermission.deniedForever) {
      permission = await _locationSource.requestPermission();
      permissionState = mapTrackingPermission(
        permission: permission,
        servicesEnabled: servicesEnabled,
      );
    }

    return permissionState;
  }

  @override
  Future<TrackingStartResult> startTracking({
    required TrackingSettings settings,
    bool requestPermissions = true,
  }) async {
    final permissionState = await ensurePermission(
      backgroundEnabled: settings.backgroundEnabled,
      requestIfNeeded: requestPermissions,
    );
    if (!permissionState.satisfiesRequirement(
      backgroundEnabled: settings.backgroundEnabled,
    )) {
      return TrackingStartResult.failure(
        permissionState: permissionState,
        message: trackingPermissionMessage(
          permissionState: permissionState,
          backgroundRequested: settings.backgroundEnabled,
        ),
      );
    }

    final enabledSettings = settings.copyWith(trackingEnabled: true);
    await _settingsStore.writeSettings(enabledSettings);

    // Android background tracking is owned by the foreground service. Other
    // modes use the direct stream managed in-process by the repository.
    if (_platformInfo.isAndroid && enabledSettings.backgroundEnabled) {
      await _notificationCoordinator.requestPermissionIfNeeded();
      await _cancelDirectRuntimeSubscriptions();
      _directTerminalTransitionStarted = false;
      await _backgroundService.startTracking();
    } else {
      if (_platformInfo.isAndroid) {
        await _backgroundService.stopTracking();
      }
      await _startDirectTracking(enabledSettings);
    }

    await _settingsStore.clearLastTrackingFailure();
    return TrackingStartResult.success(permissionState);
  }

  @override
  Future<void> stopTracking() async {
    final currentSettings = await _settingsStore.readSettings();
    await _disableTracking(
      currentSettings,
      stopBackgroundService: true,
    );
    await _settingsStore.clearLastTrackingFailure();
  }

  @override
  Future<TrackingSettings> updateTrackingSettings({
    bool? backgroundEnabled,
    int? sampleIntervalSeconds,
    int? distanceFilterMeters,
  }) async {
    final currentSettings = await _settingsStore.readSettings();
    final updatedSettings = currentSettings.copyWith(
      backgroundEnabled: backgroundEnabled,
      sampleIntervalSeconds: sampleIntervalSeconds,
      distanceFilterMeters: distanceFilterMeters,
    );
    await _settingsStore.writeSettings(updatedSettings);
    return updatedSettings;
  }

  @override
  Future<void> openAppSettings() => _locationSource.openAppSettings();

  @override
  Future<void> openLocationSettings() => _locationSource.openLocationSettings();

  Future<_NormalizedTrackingSettings> _normalizeSettingsForPermission({
    required TrackingSettings settings,
    required TrackingPermissionState permissionState,
  }) async {
    if (!settings.backgroundEnabled ||
        !permissionState.clearsSavedBackgroundPreference) {
      return _NormalizedTrackingSettings(settings: settings);
    }

    final downgradedSettings = settings.copyWith(backgroundEnabled: false);
    await _settingsStore.writeSettings(downgradedSettings);
    return _NormalizedTrackingSettings(
      settings: downgradedSettings,
      didDowngradeBackgroundPreference: true,
    );
  }

  Future<void> _startDirectTracking(TrackingSettings settings) async {
    await _cancelDirectRuntimeSubscriptions();
    _directTerminalTransitionStarted = false;

    // Watch the device-wide Location toggle directly so active sessions stop
    // promptly instead of waiting for the position stream to fail on its own.
    _serviceStatusSubscription = _locationSource.serviceStatusStream().listen(
      (status) {
        if (status == ServiceStatus.disabled) {
          unawaited(
            _handleDirectTrackingFailure(
              'Location services were disabled while tracking.',
            ),
          );
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        unawaited(_handleDirectTrackingFailure(error.toString()));
      },
    );

    _directTrackingSubscription = _locationSource
        .positionStream(
      backgroundEnabled: _platformInfo.isIos && settings.backgroundEnabled,
      sampleIntervalSeconds: settings.sampleIntervalSeconds,
      distanceFilterMeters: settings.distanceFilterMeters,
    )
        .listen(
      (position) async {
        final sample = LocationSample(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracyMeters: position.accuracy,
          capturedAtUtc: position.timestamp.toUtc(),
          source: _platformInfo.isIos ? 'ios_direct' : 'foreground',
        );
        await _persistAndPublishSample(sample);
      },
      onError: (Object error, StackTrace stackTrace) {
        unawaited(_handleDirectTrackingFailure(error.toString()));
      },
      cancelOnError: true,
    );
  }

  Future<void> _persistAndPublishSample(LocationSample sample) async {
    final persistedSample = await _database.insertSample(sample);
    await _settingsStore.writeLastKnownSample(persistedSample);
    if (_isDisposed) {
      return;
    }
    _liveUpdatesController.add(persistedSample);
  }

  Future<void> _publishBackgroundSample(LocationSample sample) async {
    await _settingsStore.writeLastKnownSample(sample);
    if (_isDisposed) {
      return;
    }
    _liveUpdatesController.add(sample);
  }

  Future<void> _handleDirectTrackingFailure(String message) async {
    if (_directTerminalTransitionStarted) {
      return;
    }
    _directTerminalTransitionStarted = true;
    await _cancelDirectRuntimeSubscriptions();

    final currentSettings = await _settingsStore.readSettings();
    if (!currentSettings.trackingEnabled) {
      return;
    }

    final permissionState = await ensurePermission(
      backgroundEnabled: currentSettings.backgroundEnabled,
    );
    final failure = classifyTrackingFailure(
      message: message,
      permissionState: permissionState,
      backgroundRequested: currentSettings.backgroundEnabled,
    );
    await _persistTrackingFailure(
      failure: failure,
      currentSettings: currentSettings,
      stopBackgroundService: true,
    );
    if (_isDisposed) {
      return;
    }
    _liveFailuresController.add(failure);
  }

  Future<void> _handleBackgroundServiceFailure(TrackingFailure failure) async {
    final currentSettings = await _settingsStore.readSettings();

    if (currentSettings.trackingEnabled) {
      await _persistTrackingFailure(
        failure: failure,
        currentSettings: currentSettings,
        stopBackgroundService: false,
      );
    } else if (await _settingsStore.readLastTrackingFailure() == null) {
      await _settingsStore.writeLastTrackingFailure(failure);
    }

    if (_isDisposed) {
      return;
    }
    _liveFailuresController.add(failure);
  }

  Future<void> _persistTrackingFailure({
    required TrackingFailure failure,
    required TrackingSettings currentSettings,
    required bool stopBackgroundService,
  }) async {
    // Failure persistence uses the same normalization rules as the background
    // isolate so both runtimes agree on whether the background request survives.
    final updatedSettings = settingsAfterTrackingFailure(
      currentSettings: currentSettings,
      permissionState: failure.permissionState,
    );
    await _settingsStore.writeSettings(updatedSettings);
    await _settingsStore.writeLastTrackingFailure(failure);
    await _disableTracking(
      updatedSettings,
      stopBackgroundService: stopBackgroundService,
    );
  }

  Future<void> _disableTracking(
    TrackingSettings settings, {
    required bool stopBackgroundService,
  }) async {
    await _settingsStore.writeSettings(
      settings.copyWith(trackingEnabled: false),
    );
    await _cancelDirectRuntimeSubscriptions();
    if (stopBackgroundService) {
      await _backgroundService.stopTracking();
    }
  }

  Future<void> _cancelDirectRuntimeSubscriptions() async {
    await _serviceStatusSubscription?.cancel();
    _serviceStatusSubscription = null;
    await _directTrackingSubscription?.cancel();
    _directTrackingSubscription = null;
  }

  @override
  Future<void> dispose() async {
    if (_isDisposed) {
      return;
    }

    _isDisposed = true;
    await _backgroundLiveUpdatesSubscription?.cancel();
    _backgroundLiveUpdatesSubscription = null;
    await _backgroundLiveFailuresSubscription?.cancel();
    _backgroundLiveFailuresSubscription = null;
    await _cancelDirectRuntimeSubscriptions();
    await _liveUpdatesController.close();
    await _liveFailuresController.close();
    await _database.close();
  }
}

class _NormalizedTrackingSettings {
  const _NormalizedTrackingSettings({
    required this.settings,
    this.didDowngradeBackgroundPreference = false,
  });

  final TrackingSettings settings;
  final bool didDowngradeBackgroundPreference;
}
