import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:location_logger/core/utils/platform_info.dart';
import 'package:location_logger/features/location_tracking/data/services/background_service_contract.dart';
import 'package:location_logger/features/location_tracking/data/services/background_tracking_entrypoint.dart';
import 'package:location_logger/features/location_tracking/domain/entities/location_sample.dart';
import 'package:location_logger/features/location_tracking/domain/models/tracking_failure.dart';

/// Coordinates the Android background service used for continuous tracking.
class AndroidBackgroundServiceManager {
  /// Creates a background service manager.
  AndroidBackgroundServiceManager({
    required PlatformInfo platformInfo,
    FlutterBackgroundService? service,
  })  : _platformInfo = platformInfo,
        _service = service ?? FlutterBackgroundService();

  final PlatformInfo _platformInfo;
  final FlutterBackgroundService _service;

  /// Configures the service entrypoints for Android and iOS.
  Future<void> configure() async {
    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: androidBackgroundTrackingEntry,
        autoStart: false,
        autoStartOnBoot: true,
        isForegroundMode: true,
        notificationChannelId: backgroundServiceChannelId,
        initialNotificationTitle: 'Location Logger',
        initialNotificationContent: 'Preparing background tracking...',
        foregroundServiceNotificationId: backgroundServiceNotificationId,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: androidBackgroundTrackingEntry,
        onBackground: iosBackgroundTrackingEntry,
      ),
    );
  }

  /// Emits samples reported by the Android background service.
  Stream<LocationSample> get liveUpdates {
    if (!_platformInfo.isAndroid) {
      return const Stream<LocationSample>.empty();
    }

    return _service
        .on(backgroundServiceLocationUpdatedEvent)
        .where((event) => event != null)
        .map(
          (event) => LocationSample.fromJson(Map<String, dynamic>.from(event!)),
        );
  }

  /// Emits structured failures reported by the Android background service.
  Stream<TrackingFailure> get liveFailures {
    if (!_platformInfo.isAndroid) {
      return const Stream<TrackingFailure>.empty();
    }

    return _service
        .on(backgroundServiceErrorEvent)
        .where((event) => event != null)
        .map(
          (event) =>
              TrackingFailure.fromJson(Map<String, dynamic>.from(event!)),
        );
  }

  /// Starts the Android background service and syncs it with saved settings.
  Future<void> startTracking() async {
    if (!_platformInfo.isAndroid) {
      return;
    }

    await _service.startService();
    _service.invoke(backgroundServiceSyncEvent);
  }

  /// Stops the Android background service if it is active.
  Future<void> stopTracking() async {
    if (!_platformInfo.isAndroid) {
      return;
    }

    _service.invoke(backgroundServiceStopEvent);
  }
}
