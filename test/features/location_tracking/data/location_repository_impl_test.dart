import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:location_logger/core/utils/platform_info.dart';
import 'package:location_logger/features/location_tracking/data/repositories/location_repository_impl.dart';
import 'package:location_logger/features/location_tracking/data/services/android_background_service.dart';
import 'package:location_logger/features/location_tracking/data/services/device_location_source.dart';
import 'package:location_logger/features/location_tracking/data/services/notification_coordinator.dart';
import 'package:location_logger/features/location_tracking/data/storage/location_database.dart';
import 'package:location_logger/features/location_tracking/data/storage/tracking_settings_store.dart';
import 'package:location_logger/features/location_tracking/domain/entities/location_sample.dart';
import 'package:location_logger/features/location_tracking/domain/models/tracking_failure.dart';
import 'package:location_logger/features/location_tracking/domain/models/tracking_permission_state.dart';
import 'package:location_logger/features/location_tracking/domain/models/tracking_settings.dart';
import 'package:mocktail/mocktail.dart';

class _MockLocationDatabase extends Mock implements LocationDatabase {}

class _MockTrackingSettingsStore extends Mock
    implements TrackingSettingsStore {}

class _MockDeviceLocationSource extends Mock implements DeviceLocationSource {}

class _MockAndroidBackgroundServiceManager extends Mock
    implements AndroidBackgroundServiceManager {}

class _MockNotificationCoordinator extends Mock
    implements NotificationCoordinator {}

class _MockPlatformInfo extends Mock implements PlatformInfo {}

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

  late LocationDatabase database;
  late TrackingSettingsStore settingsStore;
  late DeviceLocationSource locationSource;
  late AndroidBackgroundServiceManager backgroundService;
  late NotificationCoordinator notificationCoordinator;
  late PlatformInfo platformInfo;
  LocationRepositoryImpl? repository;
  late StreamController<Position> positionController;
  late StreamController<ServiceStatus> serviceStatusController;
  late StreamController<TrackingFailure> backgroundFailureController;
  late TrackingSettings currentSettings;
  late bool servicesEnabled;
  TrackingFailure? persistedFailure;

  setUp(() {
    database = _MockLocationDatabase();
    settingsStore = _MockTrackingSettingsStore();
    locationSource = _MockDeviceLocationSource();
    backgroundService = _MockAndroidBackgroundServiceManager();
    notificationCoordinator = _MockNotificationCoordinator();
    platformInfo = _MockPlatformInfo();
    positionController = StreamController<Position>.broadcast();
    serviceStatusController = StreamController<ServiceStatus>.broadcast();
    backgroundFailureController = StreamController<TrackingFailure>.broadcast();
    currentSettings = const TrackingSettings.initial();
    servicesEnabled = true;
    persistedFailure = null;

    when(() => backgroundService.liveUpdates)
        .thenAnswer((_) => const Stream<LocationSample>.empty());
    when(() => backgroundService.liveFailures)
        .thenAnswer((_) => backgroundFailureController.stream);
    when(() => settingsStore.writeSettings(any()))
        .thenAnswer((invocation) async {
      currentSettings =
          invocation.positionalArguments.first as TrackingSettings;
    });
    when(() => settingsStore.readSettings())
        .thenAnswer((_) async => currentSettings);
    when(() => settingsStore.writeLastKnownSample(any()))
        .thenAnswer((_) async {});
    when(() => settingsStore.readLastKnownSample())
        .thenAnswer((_) async => null);
    when(() => settingsStore.writeLastTrackingFailure(any()))
        .thenAnswer((invocation) async {
      persistedFailure =
          invocation.positionalArguments.first as TrackingFailure;
    });
    when(() => settingsStore.readLastTrackingFailure())
        .thenAnswer((_) async => persistedFailure);
    when(() => settingsStore.clearLastTrackingFailure()).thenAnswer((_) async {
      persistedFailure = null;
    });
    when(() => database.insertSample(any())).thenAnswer(
      (invocation) async =>
          invocation.positionalArguments.first as LocationSample,
    );
    when(() => database.close()).thenAnswer((_) async {});
    when(() => database.fetchRecentSamples(limit: any(named: 'limit')))
        .thenAnswer((_) async => const <LocationSample>[]);
    when(() => locationSource.isServiceEnabled())
        .thenAnswer((_) async => servicesEnabled);
    when(() => locationSource.checkPermission())
        .thenAnswer((_) async => LocationPermission.always);
    when(() => locationSource.requestPermission())
        .thenAnswer((_) async => LocationPermission.always);
    when(() => locationSource.serviceStatusStream())
        .thenAnswer((_) => serviceStatusController.stream);
    when(() => notificationCoordinator.requestPermissionIfNeeded())
        .thenAnswer((_) async {});
    when(() => backgroundService.startTracking()).thenAnswer((_) async {});
    when(() => backgroundService.stopTracking()).thenAnswer((_) async {});
    when(
      () => locationSource.positionStream(
        backgroundEnabled: any(named: 'backgroundEnabled'),
        sampleIntervalSeconds: any(named: 'sampleIntervalSeconds'),
        distanceFilterMeters: any(named: 'distanceFilterMeters'),
      ),
    ).thenAnswer((_) => positionController.stream);
  });

  tearDown(() async {
    await repository?.dispose();
    repository = null;
    await positionController.close();
    await serviceStatusController.close();
    await backgroundFailureController.close();
  });

  test(
    'starts Android background service and clears persisted failures on success',
    () async {
      when(() => platformInfo.isAndroid).thenReturn(true);
      when(() => platformInfo.isIos).thenReturn(false);
      persistedFailure = const TrackingFailure(
        kind: TrackingFailureKind.runtimeError,
        message: 'Old failure',
        permissionState: TrackingPermissionState.serviceDisabled,
      );

      repository = LocationRepositoryImpl(
        database: database,
        settingsStore: settingsStore,
        locationSource: locationSource,
        backgroundService: backgroundService,
        notificationCoordinator: notificationCoordinator,
        platformInfo: platformInfo,
      );

      final result = await repository!.startTracking(
        settings: const TrackingSettings(
          trackingEnabled: true,
          backgroundEnabled: true,
          sampleIntervalSeconds: 60,
          distanceFilterMeters: 10,
        ),
      );

      expect(result.didStart, isTrue);
      expect(persistedFailure, isNull);
      verify(() => notificationCoordinator.requestPermissionIfNeeded())
          .called(1);
      verify(() => backgroundService.startTracking()).called(1);
      verify(() => settingsStore.clearLastTrackingFailure()).called(1);
    },
  );

  test(
    'ensurePermission reports missing background permission without mutating state',
    () async {
      when(() => platformInfo.isAndroid).thenReturn(true);
      when(() => platformInfo.isIos).thenReturn(false);
      when(() => locationSource.checkPermission())
          .thenAnswer((_) async => LocationPermission.whileInUse);
      currentSettings = const TrackingSettings(
        trackingEnabled: true,
        backgroundEnabled: false,
        sampleIntervalSeconds: 60,
        distanceFilterMeters: 10,
      );

      repository = LocationRepositoryImpl(
        database: database,
        settingsStore: settingsStore,
        locationSource: locationSource,
        backgroundService: backgroundService,
        notificationCoordinator: notificationCoordinator,
        platformInfo: platformInfo,
      );

      final permissionState = await repository!.ensurePermission(
        backgroundEnabled: true,
      );

      expect(permissionState, TrackingPermissionState.whileInUse);
      expect(
        currentSettings,
        const TrackingSettings(
          trackingEnabled: true,
          backgroundEnabled: false,
          sampleIntervalSeconds: 60,
          distanceFilterMeters: 10,
        ),
      );
      verifyNever(() => backgroundService.stopTracking());
    },
  );

  test(
    'bootstrap keeps the saved background request during transient unavailability',
    () async {
      when(() => platformInfo.isAndroid).thenReturn(true);
      when(() => platformInfo.isIos).thenReturn(false);
      currentSettings = const TrackingSettings(
        trackingEnabled: true,
        backgroundEnabled: true,
        sampleIntervalSeconds: 60,
        distanceFilterMeters: 10,
      );
      when(() => locationSource.isServiceEnabled())
          .thenAnswer((_) async => false);

      repository = LocationRepositoryImpl(
        database: database,
        settingsStore: settingsStore,
        locationSource: locationSource,
        backgroundService: backgroundService,
        notificationCoordinator: notificationCoordinator,
        platformInfo: platformInfo,
      );

      final snapshot = await repository!.bootstrap();

      expect(snapshot.permissionState, TrackingPermissionState.serviceDisabled);
      expect(snapshot.settings.backgroundEnabled, isTrue);
      expect(snapshot.didDowngradeBackgroundPreference, isFalse);
      expect(currentSettings.backgroundEnabled, isTrue);
    },
  );

  test(
    'bootstrap clears the saved background request after a true permission downgrade',
    () async {
      when(() => platformInfo.isAndroid).thenReturn(true);
      when(() => platformInfo.isIos).thenReturn(false);
      currentSettings = const TrackingSettings(
        trackingEnabled: true,
        backgroundEnabled: true,
        sampleIntervalSeconds: 60,
        distanceFilterMeters: 10,
      );
      when(() => locationSource.checkPermission())
          .thenAnswer((_) async => LocationPermission.whileInUse);

      repository = LocationRepositoryImpl(
        database: database,
        settingsStore: settingsStore,
        locationSource: locationSource,
        backgroundService: backgroundService,
        notificationCoordinator: notificationCoordinator,
        platformInfo: platformInfo,
      );

      final snapshot = await repository!.bootstrap();

      expect(snapshot.permissionState, TrackingPermissionState.whileInUse);
      expect(snapshot.settings.backgroundEnabled, isFalse);
      expect(snapshot.didDowngradeBackgroundPreference, isTrue);
      expect(currentSettings.backgroundEnabled, isFalse);
    },
  );

  test(
    'direct stream errors emit runtime failures and persist stopped state',
    () async {
      when(() => platformInfo.isAndroid).thenReturn(false);
      when(() => platformInfo.isIos).thenReturn(true);

      repository = LocationRepositoryImpl(
        database: database,
        settingsStore: settingsStore,
        locationSource: locationSource,
        backgroundService: backgroundService,
        notificationCoordinator: notificationCoordinator,
        platformInfo: platformInfo,
      );

      final failureFuture = repository!.liveFailures.first;

      final result = await repository!.startTracking(
        settings: const TrackingSettings(
          trackingEnabled: true,
          backgroundEnabled: false,
          sampleIntervalSeconds: 60,
          distanceFilterMeters: 10,
        ),
      );

      expect(result.didStart, isTrue);

      positionController.addError(Exception('GPS signal lost'));

      final failure = await failureFuture;

      expect(
        failure,
        const TrackingFailure(
          kind: TrackingFailureKind.runtimeError,
          message: 'Exception: GPS signal lost',
          permissionState: TrackingPermissionState.always,
        ),
      );
      expect(currentSettings.trackingEnabled, isFalse);
      expect(currentSettings.backgroundEnabled, isFalse);
      expect(persistedFailure, failure);
      verify(() => backgroundService.stopTracking()).called(1);
    },
  );

  test(
    'device location services disabling stops direct tracking immediately',
    () async {
      when(() => platformInfo.isAndroid).thenReturn(false);
      when(() => platformInfo.isIos).thenReturn(true);

      repository = LocationRepositoryImpl(
        database: database,
        settingsStore: settingsStore,
        locationSource: locationSource,
        backgroundService: backgroundService,
        notificationCoordinator: notificationCoordinator,
        platformInfo: platformInfo,
      );

      final failureFuture = repository!.liveFailures.first;

      final result = await repository!.startTracking(
        settings: const TrackingSettings(
          trackingEnabled: true,
          backgroundEnabled: false,
          sampleIntervalSeconds: 60,
          distanceFilterMeters: 10,
        ),
      );

      expect(result.didStart, isTrue);

      servicesEnabled = false;
      serviceStatusController.add(ServiceStatus.disabled);

      final failure = await failureFuture;

      expect(
        failure,
        const TrackingFailure(
          kind: TrackingFailureKind.runtimeError,
          message: 'Enable location services on the device first.',
          permissionState: TrackingPermissionState.serviceDisabled,
        ),
      );
      expect(currentSettings.trackingEnabled, isFalse);
      expect(currentSettings.backgroundEnabled, isFalse);
      expect(persistedFailure, failure);
      verify(() => backgroundService.stopTracking()).called(1);
    },
  );

  test(
    'background service failures stay structured, persist stopped state, and surface on bootstrap',
    () async {
      when(() => platformInfo.isAndroid).thenReturn(true);
      when(() => platformInfo.isIos).thenReturn(false);
      currentSettings = const TrackingSettings(
        trackingEnabled: true,
        backgroundEnabled: true,
        sampleIntervalSeconds: 60,
        distanceFilterMeters: 10,
      );

      repository = LocationRepositoryImpl(
        database: database,
        settingsStore: settingsStore,
        locationSource: locationSource,
        backgroundService: backgroundService,
        notificationCoordinator: notificationCoordinator,
        platformInfo: platformInfo,
      );

      final originalFailure = const TrackingFailure(
        kind: TrackingFailureKind.runtimeError,
        message: 'Background tracking crashed.',
        permissionState: TrackingPermissionState.serviceDisabled,
      );
      final failureFuture = repository!.liveFailures.first;

      backgroundFailureController.add(originalFailure);

      final failure = await failureFuture;
      final snapshot = await repository!.bootstrap();

      expect(failure, originalFailure);
      expect(currentSettings.trackingEnabled, isFalse);
      expect(currentSettings.backgroundEnabled, isTrue);
      expect(persistedFailure, originalFailure);
      expect(snapshot.persistedFailure, originalFailure);
      expect(snapshot.settings.backgroundEnabled, isTrue);
    },
  );

  test('manual stop clears persisted failures', () async {
    when(() => platformInfo.isAndroid).thenReturn(true);
    when(() => platformInfo.isIos).thenReturn(false);
    currentSettings = const TrackingSettings(
      trackingEnabled: true,
      backgroundEnabled: true,
      sampleIntervalSeconds: 60,
      distanceFilterMeters: 10,
    );
    persistedFailure = const TrackingFailure(
      kind: TrackingFailureKind.runtimeError,
      message: 'Background tracking crashed.',
      permissionState: TrackingPermissionState.serviceDisabled,
    );

    repository = LocationRepositoryImpl(
      database: database,
      settingsStore: settingsStore,
      locationSource: locationSource,
      backgroundService: backgroundService,
      notificationCoordinator: notificationCoordinator,
      platformInfo: platformInfo,
    );

    await repository!.stopTracking();

    expect(currentSettings.trackingEnabled, isFalse);
    expect(currentSettings.backgroundEnabled, isTrue);
    expect(persistedFailure, isNull);
    verify(() => backgroundService.stopTracking()).called(1);
    verify(() => settingsStore.clearLastTrackingFailure()).called(1);
  });

  test('dispose cancels repository-owned listeners and closes the database',
      () async {
    when(() => platformInfo.isAndroid).thenReturn(true);
    when(() => platformInfo.isIos).thenReturn(false);

    repository = LocationRepositoryImpl(
      database: database,
      settingsStore: settingsStore,
      locationSource: locationSource,
      backgroundService: backgroundService,
      notificationCoordinator: notificationCoordinator,
      platformInfo: platformInfo,
    );

    await repository!.dispose();
    backgroundFailureController.add(
      const TrackingFailure(
        kind: TrackingFailureKind.runtimeError,
        message: 'Background tracking crashed.',
        permissionState: TrackingPermissionState.serviceDisabled,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(persistedFailure, isNull);
    verify(() => database.close()).called(1);
  });
}
