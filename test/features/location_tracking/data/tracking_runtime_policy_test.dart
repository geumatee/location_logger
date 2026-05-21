import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:location_logger/features/location_tracking/data/services/tracking_runtime_policy.dart';
import 'package:location_logger/features/location_tracking/domain/models/tracking_failure.dart';
import 'package:location_logger/features/location_tracking/domain/models/tracking_permission_state.dart';
import 'package:location_logger/features/location_tracking/domain/models/tracking_settings.dart';

void main() {
  test('maps geolocator permission states into tracking permission states', () {
    expect(
      mapTrackingPermission(
        permission: LocationPermission.denied,
        servicesEnabled: true,
      ),
      TrackingPermissionState.denied,
    );
    expect(
      mapTrackingPermission(
        permission: LocationPermission.deniedForever,
        servicesEnabled: true,
      ),
      TrackingPermissionState.deniedForever,
    );
    expect(
      mapTrackingPermission(
        permission: LocationPermission.whileInUse,
        servicesEnabled: true,
      ),
      TrackingPermissionState.whileInUse,
    );
    expect(
      mapTrackingPermission(
        permission: LocationPermission.always,
        servicesEnabled: true,
      ),
      TrackingPermissionState.always,
    );
    expect(
      mapTrackingPermission(
        permission: LocationPermission.unableToDetermine,
        servicesEnabled: true,
      ),
      TrackingPermissionState.unknown,
    );
    expect(
      mapTrackingPermission(
        permission: LocationPermission.always,
        servicesEnabled: false,
      ),
      TrackingPermissionState.serviceDisabled,
    );
  });

  test(
      'classifies explicit background downgrade as a background-permission failure',
      () {
    expect(
      classifyTrackingFailure(
        message: 'ignored',
        permissionState: TrackingPermissionState.whileInUse,
        backgroundRequested: true,
      ),
      const TrackingFailure(
        kind: TrackingFailureKind.backgroundPermissionDenied,
        message:
            'Tracking stopped because all the time location access is no longer available.',
        permissionState: TrackingPermissionState.whileInUse,
      ),
    );
  });

  test('classifies transient background unavailability as a runtime error', () {
    expect(
      classifyTrackingFailure(
        message: 'ignored',
        permissionState: TrackingPermissionState.serviceDisabled,
        backgroundRequested: true,
      ),
      const TrackingFailure(
        kind: TrackingFailureKind.runtimeError,
        message: 'Enable location services on the device first.',
        permissionState: TrackingPermissionState.serviceDisabled,
      ),
    );
  });

  test(
      'tracking failures serialize and deserialize with structured fields intact',
      () {
    const failure = TrackingFailure(
      kind: TrackingFailureKind.runtimeError,
      message: 'Background tracking crashed.',
      permissionState: TrackingPermissionState.serviceDisabled,
    );

    expect(TrackingFailure.fromJson(failure.toJson()), failure);
  });

  test(
      'settingsAfterTrackingFailure only clears background mode for durable downgrades',
      () {
    const currentSettings = TrackingSettings(
      trackingEnabled: true,
      backgroundEnabled: true,
      sampleIntervalSeconds: 60,
      distanceFilterMeters: 10,
    );

    expect(
      settingsAfterTrackingFailure(
        currentSettings: currentSettings,
        permissionState: TrackingPermissionState.whileInUse,
      ),
      const TrackingSettings(
        trackingEnabled: false,
        backgroundEnabled: false,
        sampleIntervalSeconds: 60,
        distanceFilterMeters: 10,
      ),
    );

    expect(
      settingsAfterTrackingFailure(
        currentSettings: currentSettings,
        permissionState: TrackingPermissionState.serviceDisabled,
      ),
      const TrackingSettings(
        trackingEnabled: false,
        backgroundEnabled: true,
        sampleIntervalSeconds: 60,
        distanceFilterMeters: 10,
      ),
    );
  });
}
