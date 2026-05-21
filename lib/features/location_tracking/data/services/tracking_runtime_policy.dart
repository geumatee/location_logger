import 'package:geolocator/geolocator.dart';
import 'package:location_logger/features/location_tracking/domain/models/tracking_failure.dart';
import 'package:location_logger/features/location_tracking/domain/models/tracking_permission_state.dart';
import 'package:location_logger/features/location_tracking/domain/models/tracking_settings.dart';

/// Maps plugin permission values into app-specific tracking states.
TrackingPermissionState mapTrackingPermission({
  required LocationPermission permission,
  required bool servicesEnabled,
}) {
  if (!servicesEnabled) {
    return TrackingPermissionState.serviceDisabled;
  }

  switch (permission) {
    case LocationPermission.denied:
      return TrackingPermissionState.denied;
    case LocationPermission.deniedForever:
      return TrackingPermissionState.deniedForever;
    case LocationPermission.whileInUse:
      return TrackingPermissionState.whileInUse;
    case LocationPermission.always:
      return TrackingPermissionState.always;
    case LocationPermission.unableToDetermine:
      return TrackingPermissionState.unknown;
  }
}

/// Classifies a runtime interruption into the structured failure model.
TrackingFailure classifyTrackingFailure({
  required String message,
  required TrackingPermissionState permissionState,
  required bool backgroundRequested,
}) {
  if (backgroundRequested && permissionState.clearsSavedBackgroundPreference) {
    return TrackingFailure(
      kind: TrackingFailureKind.backgroundPermissionDenied,
      message:
          'Tracking stopped because all the time location access is no longer available.',
      permissionState: permissionState,
    );
  }

  if (!permissionState.satisfiesRequirement(
    backgroundEnabled: backgroundRequested,
  )) {
    return TrackingFailure(
      kind: TrackingFailureKind.runtimeError,
      message: trackingPermissionMessage(
        permissionState: permissionState,
        backgroundRequested: backgroundRequested,
      ),
      permissionState: permissionState,
    );
  }

  return TrackingFailure(
    kind: TrackingFailureKind.runtimeError,
    message: message,
    permissionState: permissionState,
  );
}

/// Returns the persisted settings snapshot that should survive a failure.
///
/// Durable background-permission downgrades clear the saved background request,
/// while transient outages preserve it so the app can retry later.
TrackingSettings settingsAfterTrackingFailure({
  required TrackingSettings currentSettings,
  required TrackingPermissionState permissionState,
}) {
  return currentSettings.copyWith(
    trackingEnabled: false,
    backgroundEnabled: currentSettings.backgroundEnabled &&
        !permissionState.clearsSavedBackgroundPreference,
  );
}

/// Builds the user-facing guidance for the current permission limitation.
String trackingPermissionMessage({
  required TrackingPermissionState permissionState,
  required bool backgroundRequested,
}) {
  if (permissionState == TrackingPermissionState.serviceDisabled) {
    return 'Enable location services on the device first.';
  }

  if (permissionState == TrackingPermissionState.deniedForever) {
    return 'Location access is permanently denied. Open app settings to continue.';
  }

  if (permissionState == TrackingPermissionState.unknown) {
    if (backgroundRequested) {
      return 'Background tracking is temporarily unavailable until location access status is known.';
    }
    return 'Location access status is temporarily unavailable.';
  }

  if (backgroundRequested) {
    return 'Allow all the time location access to enable background tracking.';
  }

  return 'Allow location access to start tracking.';
}
