import 'dart:async';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:location_logger/features/location_tracking/data/services/background_service_contract.dart';
import 'package:location_logger/features/location_tracking/data/services/background_tracking_runtime.dart';
import 'package:location_logger/features/location_tracking/data/services/device_location_source.dart';
import 'package:location_logger/features/location_tracking/data/storage/location_database.dart';
import 'package:location_logger/features/location_tracking/data/storage/tracking_settings_store.dart';
import 'package:location_logger/features/location_tracking/domain/entities/location_sample.dart';
import 'package:location_logger/features/location_tracking/domain/models/tracking_failure.dart';
import 'package:location_logger/features/location_tracking/domain/models/tracking_permission_state.dart';
import 'package:location_logger/features/location_tracking/domain/models/tracking_settings.dart';
import 'package:mocktail/mocktail.dart';

class _MockServiceInstance extends Mock implements ServiceInstance {}

class _MockDeviceLocationSource extends Mock implements DeviceLocationSource {}

class _MockTrackingSettingsStore extends Mock
    implements TrackingSettingsStore {}

class _MockLocationDatabase extends Mock implements LocationDatabase {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      const TrackingSettings(
        trackingEnabled: false,
        backgroundEnabled: false,
        sampleIntervalSeconds: 60,
        distanceFilterMeters: 10,
      ),
    );
    registerFallbackValue(
      LocationSample(
        latitude: 0,
        longitude: 0,
        accuracyMeters: 0,
        capturedAtUtc: DateTime.utc(2026, 1, 1),
        source: 'fallback',
      ),
    );
    registerFallbackValue(
      const TrackingFailure(
        kind: TrackingFailureKind.runtimeError,
        message: 'fallback failure',
        permissionState: TrackingPermissionState.unknown,
      ),
    );
  });

  late ServiceInstance service;
  late DeviceLocationSource locationSource;
  late TrackingSettingsStore settingsStore;
  late LocationDatabase database;
  late StreamController<Position> positionController;
  late StreamController<ServiceStatus> serviceStatusController;
  late TrackingSettings currentSettings;
  late bool servicesEnabled;
  TrackingFailure? persistedFailure;

  setUp(() {
    service = _MockServiceInstance();
    locationSource = _MockDeviceLocationSource();
    settingsStore = _MockTrackingSettingsStore();
    database = _MockLocationDatabase();
    positionController = StreamController<Position>.broadcast();
    serviceStatusController = StreamController<ServiceStatus>.broadcast();
    currentSettings = const TrackingSettings(
      trackingEnabled: true,
      backgroundEnabled: true,
      sampleIntervalSeconds: 60,
      distanceFilterMeters: 10,
    );
    servicesEnabled = true;
    persistedFailure = null;

    when(() => service.stopSelf()).thenAnswer((_) async {});
    when(() => settingsStore.readSettings())
        .thenAnswer((_) async => currentSettings);
    when(() => settingsStore.writeSettings(any()))
        .thenAnswer((invocation) async {
      currentSettings =
          invocation.positionalArguments.first as TrackingSettings;
    });
    when(() => settingsStore.writeLastKnownSample(any()))
        .thenAnswer((_) async {});
    when(() => settingsStore.writeLastTrackingFailure(any()))
        .thenAnswer((invocation) async {
      persistedFailure =
          invocation.positionalArguments.first as TrackingFailure;
    });
    when(() => locationSource.isServiceEnabled())
        .thenAnswer((_) async => servicesEnabled);
    when(() => locationSource.checkPermission())
        .thenAnswer((_) async => LocationPermission.always);
    when(() => locationSource.serviceStatusStream())
        .thenAnswer((_) => serviceStatusController.stream);
    when(
      () => locationSource.positionStream(
        backgroundEnabled: any(named: 'backgroundEnabled'),
        sampleIntervalSeconds: any(named: 'sampleIntervalSeconds'),
        distanceFilterMeters: any(named: 'distanceFilterMeters'),
      ),
    ).thenAnswer((_) => positionController.stream);
    when(() => database.insertSample(any())).thenAnswer(
      (invocation) async =>
          invocation.positionalArguments.first as LocationSample,
    );
  });

  tearDown(() async {
    await positionController.close();
    await serviceStatusController.close();
  });

  test(
    'location service disable events stop the Android background runtime',
    () async {
      final runtime = BackgroundTrackingRuntime(
        service: service,
        locationSource: locationSource,
        settingsStore: settingsStore,
        database: database,
      );

      await runtime.startOrRefreshTracking();

      servicesEnabled = false;
      serviceStatusController.add(ServiceStatus.disabled);

      await untilCalled(() => service.stopSelf());

      expect(currentSettings.trackingEnabled, isFalse);
      expect(currentSettings.backgroundEnabled, isTrue);
      expect(
        persistedFailure,
        const TrackingFailure(
          kind: TrackingFailureKind.runtimeError,
          message: 'Enable location services on the device first.',
          permissionState: TrackingPermissionState.serviceDisabled,
        ),
      );

      final eventPayload = verify(
        () => service.invoke(backgroundServiceErrorEvent, captureAny()),
      ).captured.single as Map<String, dynamic>;
      expect(eventPayload['message'],
          'Enable location services on the device first.');
      expect(eventPayload['permissionState'], 'serviceDisabled');
      verify(() => service.stopSelf()).called(1);
    },
  );
}
