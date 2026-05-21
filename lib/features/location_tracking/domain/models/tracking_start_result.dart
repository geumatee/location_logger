import 'package:equatable/equatable.dart';
import 'package:location_logger/features/location_tracking/domain/models/tracking_permission_state.dart';

/// Outcome returned when the repository attempts to start tracking.
class TrackingStartResult extends Equatable {
  /// Creates a tracking start result.
  const TrackingStartResult({
    required this.didStart,
    required this.permissionState,
    this.errorMessage,
  });

  /// Whether tracking actually started.
  final bool didStart;

  /// Permission state observed during the start attempt.
  final TrackingPermissionState permissionState;

  /// Optional failure message to surface when start did not succeed.
  final String? errorMessage;

  /// Convenience factory for a successful start.
  factory TrackingStartResult.success(
    TrackingPermissionState permissionState,
  ) {
    return TrackingStartResult(
      didStart: true,
      permissionState: permissionState,
    );
  }

  /// Convenience factory for a failed start.
  factory TrackingStartResult.failure({
    required TrackingPermissionState permissionState,
    required String message,
  }) {
    return TrackingStartResult(
      didStart: false,
      permissionState: permissionState,
      errorMessage: message,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        didStart,
        permissionState,
        errorMessage,
      ];
}
