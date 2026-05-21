import 'package:equatable/equatable.dart';
import 'package:location_logger/features/location_tracking/domain/models/tracking_permission_state.dart';

/// Classifies the broad reason why tracking stopped or degraded.
enum TrackingFailureKind {
  /// A runtime interruption occurred while tracking was active.
  runtimeError,

  /// Background access was downgraded and the saved preference must be cleared.
  backgroundPermissionDenied,
}

/// Structured failure surfaced to the UI and persisted across relaunches.
class TrackingFailure extends Equatable {
  /// Creates a tracking failure.
  const TrackingFailure({
    required this.kind,
    required this.message,
    required this.permissionState,
  });

  /// Recreates a failure from persisted JSON.
  factory TrackingFailure.fromJson(Map<String, dynamic> json) {
    return TrackingFailure(
      kind: TrackingFailureKind.values.firstWhere(
        (value) => value.name == json['kind'],
        orElse: () => TrackingFailureKind.runtimeError,
      ),
      message: json['message'] as String? ?? 'Tracking failed.',
      permissionState: TrackingPermissionState.values.firstWhere(
        (value) => value.name == json['permissionState'],
        orElse: () => TrackingPermissionState.unknown,
      ),
    );
  }

  /// High-level failure category.
  final TrackingFailureKind kind;

  /// User-facing description of the failure.
  final String message;

  /// Permission state observed when the failure was classified.
  final TrackingPermissionState permissionState;

  /// Serializes the failure for persistence and isolate communication.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'kind': kind.name,
      'message': message,
      'permissionState': permissionState.name,
    };
  }

  @override
  List<Object?> get props => <Object?>[
        kind,
        message,
        permissionState,
      ];
}
