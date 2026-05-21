import 'dart:async';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:location_logger/features/location_tracking/data/services/background_service_contract.dart';
import 'package:location_logger/features/location_tracking/data/services/device_location_source.dart';
import 'package:location_logger/features/location_tracking/data/services/tracking_runtime_policy.dart';
import 'package:location_logger/features/location_tracking/data/storage/location_database.dart';
import 'package:location_logger/features/location_tracking/data/storage/tracking_settings_store.dart';
import 'package:location_logger/features/location_tracking/domain/entities/location_sample.dart';

/// Runs Android background tracking with a small, testable lifecycle surface.
class BackgroundTrackingRuntime {
  /// Creates a background tracking runtime.
  BackgroundTrackingRuntime({
    required ServiceInstance service,
    required DeviceLocationSource locationSource,
    required TrackingSettingsStore settingsStore,
    required LocationDatabase database,
  })  : _service = service,
        _locationSource = locationSource,
        _settingsStore = settingsStore,
        _database = database;

  final ServiceInstance _service;
  final DeviceLocationSource _locationSource;
  final TrackingSettingsStore _settingsStore;
  final LocationDatabase _database;

  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<ServiceStatus>? _serviceStatusSubscription;
  bool _terminalTransitionStarted = false;

  /// Starts tracking with the latest saved settings or refreshes an active run.
  Future<void> startOrRefreshTracking() async {
    final settings = await _settingsStore.readSettings();
    await _cancelActiveSubscriptions();
    _terminalTransitionStarted = false;

    if (!settings.trackingEnabled) {
      return;
    }

    // Watch the device-wide Location switch directly so the foreground service
    // does not keep a stale notification alive after services are disabled.
    _serviceStatusSubscription = _locationSource.serviceStatusStream().listen(
      (status) {
        if (status == ServiceStatus.disabled) {
          unawaited(
            persistTrackingFailure(
              'Location services were disabled while tracking.',
            ),
          );
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        unawaited(persistTrackingFailure(error.toString()));
      },
    );

    // Refreshing rebuilds both streams so interval or distance changes apply
    // immediately without forcing the process to restart.
    _positionSubscription = _locationSource
        .positionStream(
      backgroundEnabled: true,
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
          source: 'android_service',
        );

        await _database.insertSample(sample);
        await _settingsStore.writeLastKnownSample(sample);

        if (_service is AndroidServiceInstance) {
          await _service.setForegroundNotificationInfo(
            title: 'Location Logger active',
            content:
                'Lat ${sample.latitude.toStringAsFixed(5)} • Lng ${sample.longitude.toStringAsFixed(5)}',
          );
        }

        _service.invoke(
          backgroundServiceLocationUpdatedEvent,
          sample.toJson(),
        );
      },
      onError: (Object error, StackTrace stackTrace) async {
        await persistTrackingFailure(error.toString());
      },
    );
  }

  /// Persists a runtime failure, emits it to the foreground app, and stops.
  Future<void> persistTrackingFailure(String message) async {
    if (_terminalTransitionStarted) {
      return;
    }
    _terminalTransitionStarted = true;

    var permission = LocationPermission.unableToDetermine;
    final servicesEnabled = await _locationSource.isServiceEnabled();
    if (servicesEnabled) {
      permission = await _locationSource.checkPermission();
    }

    final permissionState = mapTrackingPermission(
      permission: permission,
      servicesEnabled: servicesEnabled,
    );
    final currentSettings = await _settingsStore.readSettings();
    final failure = classifyTrackingFailure(
      message: message,
      permissionState: permissionState,
      backgroundRequested: currentSettings.backgroundEnabled,
    );
    final updatedSettings = settingsAfterTrackingFailure(
      currentSettings: currentSettings,
      permissionState: permissionState,
    );

    await _settingsStore.writeSettings(updatedSettings);
    await _settingsStore.writeLastTrackingFailure(failure);
    _service.invoke(backgroundServiceErrorEvent, failure.toJson());
    await _cancelActiveSubscriptions();
    await _service.stopSelf();
  }

  /// Stops tracking without recording a failure.
  Future<void> stop() async {
    if (_terminalTransitionStarted) {
      return;
    }
    _terminalTransitionStarted = true;
    await _cancelActiveSubscriptions();
    await _service.stopSelf();
  }

  Future<void> _cancelActiveSubscriptions() async {
    await _serviceStatusSubscription?.cancel();
    _serviceStatusSubscription = null;
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }
}
