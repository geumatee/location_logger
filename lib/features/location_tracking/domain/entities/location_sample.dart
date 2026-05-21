import 'package:equatable/equatable.dart';

/// Immutable location sample captured by foreground or background tracking.
class LocationSample extends Equatable {
  /// Creates a location sample.
  const LocationSample({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.capturedAtUtc,
    required this.source,
    this.id,
  });

  /// Database identifier assigned after persistence.
  final int? id;

  /// Recorded latitude in decimal degrees.
  final double latitude;

  /// Recorded longitude in decimal degrees.
  final double longitude;

  /// Horizontal accuracy reported by the platform, in meters.
  final double accuracyMeters;

  /// Timestamp of the sample normalized to UTC.
  final DateTime capturedAtUtc;

  /// Identifier for the runtime path that produced the sample.
  final String source;

  /// Returns a copy of the sample with the provided field overrides.
  LocationSample copyWith({
    int? id,
    double? latitude,
    double? longitude,
    double? accuracyMeters,
    DateTime? capturedAtUtc,
    String? source,
  }) {
    return LocationSample(
      id: id ?? this.id,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracyMeters: accuracyMeters ?? this.accuracyMeters,
      capturedAtUtc: capturedAtUtc ?? this.capturedAtUtc,
      source: source ?? this.source,
    );
  }

  /// Serializes the sample for preferences or service channel transport.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'latitude': latitude,
      'longitude': longitude,
      'accuracyMeters': accuracyMeters,
      'capturedAtUtc': capturedAtUtc.toIso8601String(),
      'source': source,
    };
  }

  /// Serializes the sample into the SQLite row format used by the repository.
  Map<String, Object?> toDatabaseMap() {
    return <String, Object?>{
      if (id != null) 'id': id,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy_meters': accuracyMeters,
      'captured_at_utc': capturedAtUtc.toIso8601String(),
      'source': source,
    };
  }

  /// Recreates a sample from JSON storage or service payloads.
  static LocationSample fromJson(Map<String, dynamic> json) {
    return LocationSample(
      id: json['id'] as int?,
      latitude: _toDouble(json['latitude']),
      longitude: _toDouble(json['longitude']),
      accuracyMeters: _toDouble(json['accuracyMeters']),
      capturedAtUtc: DateTime.parse(json['capturedAtUtc'] as String).toUtc(),
      source: json['source'] as String,
    );
  }

  /// Recreates a sample from a SQLite query row.
  static LocationSample fromDatabaseMap(Map<String, Object?> map) {
    return LocationSample(
      id: map['id'] as int?,
      latitude: _toDouble(map['latitude']),
      longitude: _toDouble(map['longitude']),
      accuracyMeters: _toDouble(map['accuracy_meters']),
      capturedAtUtc: DateTime.parse(map['captured_at_utc'] as String).toUtc(),
      source: map['source'] as String,
    );
  }

  static double _toDouble(Object? value) {
    if (value is int) {
      return value.toDouble();
    }
    return (value as num).toDouble();
  }

  @override
  List<Object?> get props => <Object?>[
        id,
        latitude,
        longitude,
        accuracyMeters,
        capturedAtUtc,
        source,
      ];
}
