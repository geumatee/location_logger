/// Permission states normalized from platform-specific location APIs.
enum TrackingPermissionState {
  /// The runtime could not determine the current permission state yet.
  unknown,

  /// Device-wide location services are disabled.
  serviceDisabled,

  /// The app does not currently have location permission.
  denied,

  /// The app permission was denied permanently and requires manual recovery.
  deniedForever,

  /// Foreground access is available, but continuous background access is not.
  whileInUse,

  /// Foreground and background access are both available.
  always,
}

/// Convenience helpers for reasoning about permission-driven tracking behavior.
extension TrackingPermissionStateX on TrackingPermissionState {
  /// Whether the current permission state satisfies the requested mode.
  bool satisfiesRequirement({required bool backgroundEnabled}) {
    if (backgroundEnabled) {
      return this == TrackingPermissionState.always;
    }
    return this == TrackingPermissionState.whileInUse ||
        this == TrackingPermissionState.always;
  }

  /// Whether the saved background preference should be cleared permanently.
  bool get clearsSavedBackgroundPreference {
    return this == TrackingPermissionState.whileInUse ||
        this == TrackingPermissionState.denied ||
        this == TrackingPermissionState.deniedForever;
  }

  /// Whether the background toggle should be disabled in the UI.
  bool get locksBackgroundToggle => clearsSavedBackgroundPreference;

  /// Whether the limitation may recover without changing the saved preference.
  bool get isTransientlyUnavailable {
    return this == TrackingPermissionState.serviceDisabled ||
        this == TrackingPermissionState.unknown;
  }

  /// Whether background tracking can run effectively for the current request.
  bool effectiveBackgroundEnabled({required bool backgroundRequested}) {
    return backgroundRequested && this == TrackingPermissionState.always;
  }

  /// Human-readable status label for the dashboard.
  String get label {
    switch (this) {
      case TrackingPermissionState.unknown:
        return 'Unknown';
      case TrackingPermissionState.serviceDisabled:
        return 'Location services disabled';
      case TrackingPermissionState.denied:
        return 'Permission denied';
      case TrackingPermissionState.deniedForever:
        return 'Permission denied forever';
      case TrackingPermissionState.whileInUse:
        return 'While in use';
      case TrackingPermissionState.always:
        return 'Always';
    }
  }
}
