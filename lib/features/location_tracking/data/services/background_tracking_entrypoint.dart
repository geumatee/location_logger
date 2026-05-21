import 'dart:async';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:location_logger/features/location_tracking/data/services/background_service_contract.dart';
import 'package:location_logger/features/location_tracking/data/services/background_tracking_runtime.dart';
import 'package:location_logger/features/location_tracking/data/services/device_location_source.dart';
import 'package:location_logger/features/location_tracking/data/storage/location_database.dart';
import 'package:location_logger/features/location_tracking/data/storage/tracking_settings_store.dart';

/// iOS background entrypoint required by `flutter_background_service`.
@pragma('vm:entry-point')
Future<bool> iosBackgroundTrackingEntry(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

/// Android background isolate entrypoint used by the foreground service.
@pragma('vm:entry-point')
void androidBackgroundTrackingEntry(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  // The service runs in a background isolate, so it rebuilds its own minimal
  // dependencies instead of relying on the app's GetIt container.
  final runtime = BackgroundTrackingRuntime(
    service: service,
    locationSource: DeviceLocationSource(),
    settingsStore: TrackingSettingsStore(),
    database: LocationDatabase(),
  );

  service.on(backgroundServiceSyncEvent).listen((_) async {
    await runtime.startOrRefreshTracking();
  });

  service.on(backgroundServiceStopEvent).listen((_) async {
    await runtime.stop();
  });

  await runtime.startOrRefreshTracking();
}
