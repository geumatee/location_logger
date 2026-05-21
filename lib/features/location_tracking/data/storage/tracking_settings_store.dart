import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:location_logger/features/location_tracking/domain/entities/location_sample.dart';
import 'package:location_logger/features/location_tracking/domain/models/tracking_failure.dart';
import 'package:location_logger/features/location_tracking/domain/models/tracking_settings.dart';

/// Persists lightweight tracking state needed across app launches.
class TrackingSettingsStore {
  /// Creates a tracking settings store.
  TrackingSettingsStore({SharedPreferencesAsync? preferences})
      : _preferences = preferences ?? SharedPreferencesAsync();

  static const String _trackingEnabledKey = 'tracking_enabled';
  static const String _backgroundEnabledKey = 'background_enabled';
  static const String _sampleIntervalKey = 'sample_interval_seconds';
  static const String _distanceFilterKey = 'distance_filter_meters';
  static const String _lastKnownSampleKey = 'last_known_sample';
  static const String _lastTrackingFailureKey = 'last_tracking_failure';

  final SharedPreferencesAsync _preferences;

  /// Reads the persisted tracking settings.
  Future<TrackingSettings> readSettings() async {
    final trackingEnabled =
        await _preferences.getBool(_trackingEnabledKey) ?? false;
    final backgroundEnabled =
        await _preferences.getBool(_backgroundEnabledKey) ?? false;
    final sampleInterval = await _preferences.getInt(_sampleIntervalKey) ?? 60;
    final distanceFilter = await _preferences.getInt(_distanceFilterKey) ?? 10;

    return TrackingSettings(
      trackingEnabled: trackingEnabled,
      backgroundEnabled: backgroundEnabled,
      sampleIntervalSeconds: sampleInterval,
      distanceFilterMeters: distanceFilter,
    );
  }

  /// Writes the persisted tracking settings.
  Future<void> writeSettings(TrackingSettings settings) async {
    await _preferences.setBool(_trackingEnabledKey, settings.trackingEnabled);
    await _preferences.setBool(
        _backgroundEnabledKey, settings.backgroundEnabled);
    await _preferences.setInt(
      _sampleIntervalKey,
      settings.sampleIntervalSeconds,
    );
    await _preferences.setInt(
      _distanceFilterKey,
      settings.distanceFilterMeters,
    );
  }

  /// Persists the latest known sample for fast UI restoration.
  Future<void> writeLastKnownSample(LocationSample sample) async {
    await _preferences.setString(
      _lastKnownSampleKey,
      jsonEncode(sample.toJson()),
    );
  }

  /// Reads the last known sample if one has been persisted.
  Future<LocationSample?> readLastKnownSample() async {
    final raw = await _preferences.getString(_lastKnownSampleKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return LocationSample.fromJson(decoded);
  }

  /// Persists the latest structured tracking failure.
  Future<void> writeLastTrackingFailure(TrackingFailure failure) async {
    await _preferences.setString(
      _lastTrackingFailureKey,
      jsonEncode(failure.toJson()),
    );
  }

  /// Reads the last structured tracking failure if present.
  Future<TrackingFailure?> readLastTrackingFailure() async {
    final raw = await _preferences.getString(_lastTrackingFailureKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return TrackingFailure.fromJson(decoded);
  }

  /// Clears any persisted tracking failure.
  Future<void> clearLastTrackingFailure() async {
    await _preferences.remove(_lastTrackingFailureKey);
  }
}
