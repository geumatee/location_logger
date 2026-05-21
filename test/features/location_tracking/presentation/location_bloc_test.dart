import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_logger/features/location_tracking/domain/entities/location_sample.dart';
import 'package:location_logger/features/location_tracking/domain/models/tracking_bootstrap_snapshot.dart';
import 'package:location_logger/features/location_tracking/domain/models/tracking_failure.dart';
import 'package:location_logger/features/location_tracking/domain/models/tracking_permission_state.dart';
import 'package:location_logger/features/location_tracking/domain/models/tracking_settings.dart';
import 'package:location_logger/features/location_tracking/domain/models/tracking_start_result.dart';
import 'package:location_logger/features/location_tracking/domain/repositories/location_repository.dart';
import 'package:location_logger/features/location_tracking/presentation/bloc/location_bloc.dart';
import 'package:mocktail/mocktail.dart';

class _MockLocationRepository extends Mock implements LocationRepository {}

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
  });

  late LocationRepository repository;
  late StreamController<LocationSample> updatesController;
  late StreamController<TrackingFailure> failuresController;

  final sample = LocationSample(
    latitude: 35.6812,
    longitude: 139.7671,
    accuracyMeters: 5,
    capturedAtUtc: DateTime.utc(2026, 5, 20, 1),
    source: 'test',
  );

  setUp(() {
    repository = _MockLocationRepository();
    updatesController = StreamController<LocationSample>.broadcast();
    failuresController = StreamController<TrackingFailure>.broadcast();

    TrackingSettings updatedSettingsFromInvocation(Invocation invocation) {
      return TrackingSettings(
        trackingEnabled: false,
        backgroundEnabled:
            invocation.namedArguments[#backgroundEnabled] as bool? ?? false,
        sampleIntervalSeconds:
            invocation.namedArguments[#sampleIntervalSeconds] as int? ?? 60,
        distanceFilterMeters:
            invocation.namedArguments[#distanceFilterMeters] as int? ?? 10,
      );
    }

    when(() => repository.liveUpdates)
        .thenAnswer((_) => updatesController.stream);
    when(() => repository.liveFailures)
        .thenAnswer((_) => failuresController.stream);
    when(() => repository.bootstrap(recentLimit: 5)).thenAnswer(
      (_) async => const TrackingBootstrapSnapshot(
        settings: TrackingSettings(
          trackingEnabled: false,
          backgroundEnabled: false,
          sampleIntervalSeconds: 60,
          distanceFilterMeters: 10,
        ),
        permissionState: TrackingPermissionState.always,
        recentSamples: <LocationSample>[],
      ),
    );
    when(
      () => repository.ensurePermission(
        backgroundEnabled: any(named: 'backgroundEnabled'),
        requestIfNeeded: any(named: 'requestIfNeeded'),
      ),
    ).thenAnswer((_) async => TrackingPermissionState.always);
    when(
      () => repository.startTracking(
        settings: any(named: 'settings'),
        requestPermissions: any(named: 'requestPermissions'),
      ),
    ).thenAnswer(
      (_) async => TrackingStartResult.success(
        TrackingPermissionState.always,
      ),
    );
    when(() => repository.stopTracking()).thenAnswer((_) async {});
    when(
      () => repository.updateTrackingSettings(
        backgroundEnabled: any(named: 'backgroundEnabled'),
      ),
    ).thenAnswer(
        (invocation) async => updatedSettingsFromInvocation(invocation));
    when(
      () => repository.updateTrackingSettings(
        sampleIntervalSeconds: any(named: 'sampleIntervalSeconds'),
      ),
    ).thenAnswer(
        (invocation) async => updatedSettingsFromInvocation(invocation));
    when(
      () => repository.updateTrackingSettings(
        distanceFilterMeters: any(named: 'distanceFilterMeters'),
      ),
    ).thenAnswer(
        (invocation) async => updatedSettingsFromInvocation(invocation));
    when(
      () => repository.updateTrackingSettings(
        backgroundEnabled: any(named: 'backgroundEnabled'),
        sampleIntervalSeconds: any(named: 'sampleIntervalSeconds'),
        distanceFilterMeters: any(named: 'distanceFilterMeters'),
      ),
    ).thenAnswer(
        (invocation) async => updatedSettingsFromInvocation(invocation));
    when(() => repository.openAppSettings()).thenAnswer((_) async {});
    when(() => repository.openLocationSettings()).thenAnswer((_) async {});
  });

  tearDown(() async {
    await updatesController.close();
    await failuresController.close();
  });

  blocTest<LocationBloc, LocationState>(
    'bootstrapping with always permission keeps background tracking effective',
    build: () {
      when(() => repository.bootstrap(recentLimit: 5)).thenAnswer(
        (_) async => const TrackingBootstrapSnapshot(
          settings: TrackingSettings(
            trackingEnabled: true,
            backgroundEnabled: true,
            sampleIntervalSeconds: 60,
            distanceFilterMeters: 10,
          ),
          permissionState: TrackingPermissionState.always,
          recentSamples: <LocationSample>[],
        ),
      );
      when(
        () => repository.startTracking(
          settings: any(named: 'settings'),
          requestPermissions: any(named: 'requestPermissions'),
        ),
      ).thenAnswer(
        (_) async => TrackingStartResult.success(
          TrackingPermissionState.always,
        ),
      );
      return LocationBloc(repository);
    },
    act: (bloc) => bloc.add(const LocationAppBootstrapped()),
    expect: () => <Matcher>[
      isA<LocationState>()
          .having((state) => state.isLoading, 'isLoading', true),
      isA<LocationState>()
          .having((state) => state.trackingEnabled, 'trackingEnabled', true)
          .having((state) => state.backgroundEnabled, 'backgroundEnabled', true)
          .having(
            (state) => state.effectiveBackgroundEnabled,
            'effectiveBackgroundEnabled',
            true,
          )
          .having(
            (state) => state.isBackgroundToggleLocked,
            'isBackgroundToggleLocked',
            false,
          )
          .having(
            (state) => state.backgroundTrackingMessage,
            'backgroundTrackingMessage',
            isNull,
          ),
    ],
    verify: (_) {
      verify(
        () => repository.startTracking(
          settings: const TrackingSettings(
            trackingEnabled: true,
            backgroundEnabled: true,
            sampleIntervalSeconds: 60,
            distanceFilterMeters: 10,
          ),
          requestPermissions: false,
        ),
      ).called(1);
    },
  );

  blocTest<LocationBloc, LocationState>(
    'bootstrapping with while-in-use permission locks the background toggle',
    build: () {
      when(() => repository.bootstrap(recentLimit: 5)).thenAnswer(
        (_) async => const TrackingBootstrapSnapshot(
          settings: TrackingSettings(
            trackingEnabled: false,
            backgroundEnabled: true,
            sampleIntervalSeconds: 60,
            distanceFilterMeters: 10,
          ),
          permissionState: TrackingPermissionState.whileInUse,
          recentSamples: <LocationSample>[],
        ),
      );
      return LocationBloc(repository);
    },
    act: (bloc) => bloc.add(const LocationAppBootstrapped()),
    expect: () => <Matcher>[
      isA<LocationState>()
          .having((state) => state.isLoading, 'isLoading', true),
      isA<LocationState>()
          .having((state) => state.backgroundEnabled, 'backgroundEnabled', true)
          .having(
            (state) => state.isBackgroundToggleLocked,
            'isBackgroundToggleLocked',
            true,
          )
          .having(
            (state) => state.backgroundTrackingMessage,
            'backgroundTrackingMessage',
            LocationBloc.backgroundPermissionMessage,
          ),
    ],
  );

  blocTest<LocationBloc, LocationState>(
    'bootstrapping with denied forever permission shows settings guidance',
    build: () {
      when(() => repository.bootstrap(recentLimit: 5)).thenAnswer(
        (_) async => const TrackingBootstrapSnapshot(
          settings: TrackingSettings(
            trackingEnabled: false,
            backgroundEnabled: true,
            sampleIntervalSeconds: 60,
            distanceFilterMeters: 10,
          ),
          permissionState: TrackingPermissionState.deniedForever,
          recentSamples: <LocationSample>[],
        ),
      );
      return LocationBloc(repository);
    },
    act: (bloc) => bloc.add(const LocationAppBootstrapped()),
    expect: () => <Matcher>[
      isA<LocationState>()
          .having((state) => state.isLoading, 'isLoading', true),
      isA<LocationState>()
          .having(
            (state) => state.isBackgroundToggleLocked,
            'isBackgroundToggleLocked',
            true,
          )
          .having(
            (state) => state.backgroundTrackingMessage,
            'backgroundTrackingMessage',
            'Location access is permanently denied. Open app settings to continue.',
          ),
    ],
  );

  blocTest<LocationBloc, LocationState>(
    'bootstrapping with unknown permission keeps the request but marks it unavailable',
    build: () {
      when(() => repository.bootstrap(recentLimit: 5)).thenAnswer(
        (_) async => const TrackingBootstrapSnapshot(
          settings: TrackingSettings(
            trackingEnabled: false,
            backgroundEnabled: true,
            sampleIntervalSeconds: 60,
            distanceFilterMeters: 10,
          ),
          permissionState: TrackingPermissionState.unknown,
          recentSamples: <LocationSample>[],
        ),
      );
      return LocationBloc(repository);
    },
    act: (bloc) => bloc.add(const LocationAppBootstrapped()),
    expect: () => <Matcher>[
      isA<LocationState>()
          .having((state) => state.isLoading, 'isLoading', true),
      isA<LocationState>()
          .having((state) => state.backgroundEnabled, 'backgroundEnabled', true)
          .having(
            (state) => state.isBackgroundToggleLocked,
            'isBackgroundToggleLocked',
            false,
          )
          .having(
            (state) => state.backgroundTrackingMessage,
            'backgroundTrackingMessage',
            'Background tracking is requested, but the current location access status is not available yet.',
          ),
    ],
  );

  blocTest<LocationBloc, LocationState>(
    'hydrates a persisted failure while keeping requested and effective background modes split',
    build: () {
      when(() => repository.bootstrap(recentLimit: 5)).thenAnswer(
        (_) async => TrackingBootstrapSnapshot(
          settings: const TrackingSettings(
            trackingEnabled: false,
            backgroundEnabled: true,
            sampleIntervalSeconds: 60,
            distanceFilterMeters: 10,
          ),
          permissionState: TrackingPermissionState.serviceDisabled,
          recentSamples: <LocationSample>[sample],
          lastKnownSample: sample,
          persistedFailure: const TrackingFailure(
            kind: TrackingFailureKind.runtimeError,
            message: 'Tracking interrupted.',
            permissionState: TrackingPermissionState.serviceDisabled,
          ),
        ),
      );
      return LocationBloc(repository);
    },
    act: (bloc) => bloc.add(const LocationAppBootstrapped()),
    expect: () => <Matcher>[
      isA<LocationState>()
          .having((state) => state.isLoading, 'isLoading', true),
      isA<LocationState>()
          .having((state) => state.hasLoaded, 'hasLoaded', true)
          .having((state) => state.trackingEnabled, 'trackingEnabled', false)
          .having((state) => state.backgroundEnabled, 'backgroundEnabled', true)
          .having(
            (state) => state.effectiveBackgroundEnabled,
            'effectiveBackgroundEnabled',
            false,
          )
          .having((state) => state.currentSample, 'currentSample', sample)
          .having(
            (state) => state.recentSamples,
            'recentSamples',
            <LocationSample>[sample],
          )
          .having(
            (state) => state.errorMessage,
            'errorMessage',
            'Tracking interrupted.',
          )
          .having(
            (state) => state.backgroundTrackingMessage,
            'backgroundTrackingMessage',
            'Background tracking is requested, but location services are currently turned off.',
          ),
    ],
  );

  blocTest<LocationBloc, LocationState>(
    'starts tracking after an explicit request',
    build: () => LocationBloc(repository),
    seed: () => const LocationState.initial().copyWith(hasLoaded: true),
    act: (bloc) => bloc.add(const LocationStartRequested()),
    expect: () => <Matcher>[
      isA<LocationState>()
          .having((state) => state.isLoading, 'isLoading', true),
      isA<LocationState>()
          .having((state) => state.trackingEnabled, 'trackingEnabled', true)
          .having(
            (state) => state.effectiveBackgroundEnabled,
            'effectiveBackgroundEnabled',
            false,
          )
          .having((state) => state.isLoading, 'isLoading', false),
    ],
  );

  blocTest<LocationBloc, LocationState>(
    'start request falls back to foreground tracking after a background downgrade',
    build: () {
      when(
        () => repository.startTracking(
          settings: const TrackingSettings(
            trackingEnabled: true,
            backgroundEnabled: true,
            sampleIntervalSeconds: 60,
            distanceFilterMeters: 10,
          ),
          requestPermissions: true,
        ),
      ).thenAnswer(
        (_) async => TrackingStartResult.failure(
          permissionState: TrackingPermissionState.whileInUse,
          message: LocationBloc.backgroundPermissionMessage,
        ),
      );
      when(
        () => repository.startTracking(
          settings: const TrackingSettings(
            trackingEnabled: true,
            backgroundEnabled: false,
            sampleIntervalSeconds: 60,
            distanceFilterMeters: 10,
          ),
          requestPermissions: false,
        ),
      ).thenAnswer(
        (_) async => TrackingStartResult.success(
          TrackingPermissionState.whileInUse,
        ),
      );
      return LocationBloc(repository);
    },
    seed: () => const LocationState.initial().copyWith(
      hasLoaded: true,
      backgroundEnabled: true,
    ),
    act: (bloc) => bloc.add(const LocationStartRequested()),
    expect: () => <Matcher>[
      isA<LocationState>()
          .having((state) => state.isLoading, 'isLoading', true),
      isA<LocationState>()
          .having((state) => state.isLoading, 'isLoading', false)
          .having((state) => state.trackingEnabled, 'trackingEnabled', true)
          .having(
              (state) => state.backgroundEnabled, 'backgroundEnabled', false)
          .having(
            (state) => state.effectiveBackgroundEnabled,
            'effectiveBackgroundEnabled',
            false,
          )
          .having(
            (state) => state.isBackgroundToggleLocked,
            'isBackgroundToggleLocked',
            true,
          )
          .having(
            (state) => state.backgroundTrackingMessage,
            'backgroundTrackingMessage',
            LocationBloc.backgroundPermissionMessage,
          ),
    ],
    verify: (_) {
      verify(
        () => repository.updateTrackingSettings(backgroundEnabled: false),
      ).called(1);
      verify(
        () => repository.startTracking(
          settings: const TrackingSettings(
            trackingEnabled: true,
            backgroundEnabled: true,
            sampleIntervalSeconds: 60,
            distanceFilterMeters: 10,
          ),
          requestPermissions: true,
        ),
      ).called(1);
      verify(
        () => repository.startTracking(
          settings: const TrackingSettings(
            trackingEnabled: true,
            backgroundEnabled: false,
            sampleIntervalSeconds: 60,
            distanceFilterMeters: 10,
          ),
          requestPermissions: false,
        ),
      ).called(1);
    },
  );

  blocTest<LocationBloc, LocationState>(
    'folds live updates into current sample and recent history',
    build: () => LocationBloc(repository),
    seed: () => const LocationState.initial().copyWith(hasLoaded: true),
    act: (bloc) async {
      bloc.add(const LocationAppBootstrapped());
      await Future<void>.delayed(Duration.zero);
      updatesController.add(sample);
    },
    expect: () => <Matcher>[
      isA<LocationState>()
          .having((state) => state.isLoading, 'isLoading', true),
      isA<LocationState>()
          .having((state) => state.hasLoaded, 'hasLoaded', true),
      isA<LocationState>()
          .having((state) => state.currentSample, 'currentSample', sample)
          .having((state) => state.recentSamples.length, 'recentSamples', 1),
    ],
  );

  blocTest<LocationBloc, LocationState>(
    'keeps a requested background toggle on during transient preflight failure without restarting tracking',
    build: () {
      when(
        () => repository.ensurePermission(
          backgroundEnabled: true,
          requestIfNeeded: true,
        ),
      ).thenAnswer((_) async => TrackingPermissionState.serviceDisabled);
      return LocationBloc(repository);
    },
    seed: () => const LocationState.initial().copyWith(
      hasLoaded: true,
      trackingEnabled: true,
      permissionState: TrackingPermissionState.always,
    ),
    act: (bloc) => bloc.add(const BackgroundTrackingToggled(true)),
    expect: () => <Matcher>[
      isA<LocationState>()
          .having((state) => state.isLoading, 'isLoading', true),
      isA<LocationState>()
          .having((state) => state.isLoading, 'isLoading', true)
          .having((state) => state.backgroundEnabled, 'backgroundEnabled', true)
          .having(
            (state) => state.effectiveBackgroundEnabled,
            'effectiveBackgroundEnabled',
            false,
          ),
      isA<LocationState>()
          .having((state) => state.isLoading, 'isLoading', false)
          .having((state) => state.trackingEnabled, 'trackingEnabled', true)
          .having((state) => state.backgroundEnabled, 'backgroundEnabled', true)
          .having(
            (state) => state.effectiveBackgroundEnabled,
            'effectiveBackgroundEnabled',
            false,
          )
          .having(
            (state) => state.isBackgroundToggleLocked,
            'isBackgroundToggleLocked',
            false,
          )
          .having(
            (state) => state.backgroundTrackingMessage,
            'backgroundTrackingMessage',
            'Background tracking is requested, but location services are currently turned off.',
          ),
    ],
    verify: (_) {
      verify(
        () => repository.updateTrackingSettings(backgroundEnabled: true),
      ).called(1);
      verifyNever(() => repository.stopTracking());
      verifyNever(
        () => repository.startTracking(
          settings: any(named: 'settings'),
          requestPermissions: any(named: 'requestPermissions'),
        ),
      );
    },
  );

  blocTest<LocationBloc, LocationState>(
    'clears the requested background mode and locks the switch on explicit permission failure',
    build: () {
      when(
        () => repository.ensurePermission(
          backgroundEnabled: true,
          requestIfNeeded: true,
        ),
      ).thenAnswer((_) async => TrackingPermissionState.whileInUse);
      return LocationBloc(repository);
    },
    seed: () => const LocationState.initial().copyWith(
      hasLoaded: true,
      trackingEnabled: true,
      permissionState: TrackingPermissionState.always,
    ),
    act: (bloc) => bloc.add(const BackgroundTrackingToggled(true)),
    expect: () => <Matcher>[
      isA<LocationState>()
          .having((state) => state.isLoading, 'isLoading', true),
      isA<LocationState>()
          .having((state) => state.isLoading, 'isLoading', false)
          .having((state) => state.trackingEnabled, 'trackingEnabled', true)
          .having(
              (state) => state.backgroundEnabled, 'backgroundEnabled', false)
          .having(
            (state) => state.effectiveBackgroundEnabled,
            'effectiveBackgroundEnabled',
            false,
          )
          .having(
            (state) => state.isBackgroundToggleLocked,
            'isBackgroundToggleLocked',
            true,
          )
          .having(
            (state) => state.backgroundTrackingMessage,
            'backgroundTrackingMessage',
            LocationBloc.backgroundPermissionMessage,
          ),
    ],
    verify: (_) {
      verify(
        () => repository.updateTrackingSettings(backgroundEnabled: false),
      ).called(1);
      verifyNever(() => repository.stopTracking());
      verifyNever(
        () => repository.startTracking(
          settings: any(named: 'settings'),
          requestPermissions: any(named: 'requestPermissions'),
        ),
      );
    },
  );

  blocTest<LocationBloc, LocationState>(
    'refresh restarts foreground tracking after a true background preference downgrade',
    build: () {
      when(() => repository.bootstrap(recentLimit: 5)).thenAnswer(
        (_) async => const TrackingBootstrapSnapshot(
          settings: TrackingSettings(
            trackingEnabled: true,
            backgroundEnabled: false,
            sampleIntervalSeconds: 60,
            distanceFilterMeters: 10,
          ),
          permissionState: TrackingPermissionState.whileInUse,
          recentSamples: <LocationSample>[],
          didDowngradeBackgroundPreference: true,
        ),
      );
      when(
        () => repository.startTracking(
          settings: any(named: 'settings'),
          requestPermissions: any(named: 'requestPermissions'),
        ),
      ).thenAnswer(
        (_) async => TrackingStartResult.success(
          TrackingPermissionState.whileInUse,
        ),
      );
      return LocationBloc(repository);
    },
    seed: () => const LocationState.initial().copyWith(
      hasLoaded: true,
      trackingEnabled: true,
      backgroundEnabled: true,
      effectiveBackgroundEnabled: true,
      permissionState: TrackingPermissionState.always,
    ),
    act: (bloc) => bloc.add(const LocationStatusRefreshRequested()),
    expect: () => <Matcher>[
      isA<LocationState>()
          .having(
              (state) => state.backgroundEnabled, 'backgroundEnabled', false)
          .having(
            (state) => state.effectiveBackgroundEnabled,
            'effectiveBackgroundEnabled',
            false,
          )
          .having((state) => state.trackingEnabled, 'trackingEnabled', true)
          .having(
            (state) => state.isBackgroundToggleLocked,
            'isBackgroundToggleLocked',
            true,
          ),
    ],
    verify: (_) {
      verify(
        () => repository.startTracking(
          settings: const TrackingSettings(
            trackingEnabled: true,
            backgroundEnabled: false,
            sampleIntervalSeconds: 60,
            distanceFilterMeters: 10,
          ),
          requestPermissions: false,
        ),
      ).called(1);
    },
  );

  blocTest<LocationBloc, LocationState>(
    'runtime failures stop tracking, preserve the last sample, and keep the requested background mode',
    build: () {
      when(() => repository.bootstrap(recentLimit: 5)).thenAnswer(
        (_) async => TrackingBootstrapSnapshot(
          settings: const TrackingSettings(
            trackingEnabled: true,
            backgroundEnabled: true,
            sampleIntervalSeconds: 60,
            distanceFilterMeters: 10,
          ),
          permissionState: TrackingPermissionState.always,
          recentSamples: <LocationSample>[sample],
          lastKnownSample: sample,
        ),
      );
      when(
        () => repository.startTracking(
          settings: any(named: 'settings'),
          requestPermissions: any(named: 'requestPermissions'),
        ),
      ).thenAnswer(
        (_) async => TrackingStartResult.success(
          TrackingPermissionState.always,
        ),
      );
      return LocationBloc(repository);
    },
    act: (bloc) async {
      bloc.add(const LocationAppBootstrapped());
      await Future<void>.delayed(Duration.zero);
      failuresController.add(
        const TrackingFailure(
          kind: TrackingFailureKind.runtimeError,
          message: 'Tracking interrupted.',
          permissionState: TrackingPermissionState.serviceDisabled,
        ),
      );
    },
    expect: () => <Matcher>[
      isA<LocationState>()
          .having((state) => state.isLoading, 'isLoading', true),
      isA<LocationState>()
          .having((state) => state.backgroundEnabled, 'backgroundEnabled', true)
          .having(
            (state) => state.effectiveBackgroundEnabled,
            'effectiveBackgroundEnabled',
            true,
          )
          .having((state) => state.currentSample, 'currentSample', sample),
      isA<LocationState>()
          .having((state) => state.trackingEnabled, 'trackingEnabled', false)
          .having((state) => state.backgroundEnabled, 'backgroundEnabled', true)
          .having(
            (state) => state.effectiveBackgroundEnabled,
            'effectiveBackgroundEnabled',
            false,
          )
          .having((state) => state.currentSample, 'currentSample', sample)
          .having(
            (state) => state.recentSamples,
            'recentSamples',
            <LocationSample>[sample],
          )
          .having(
            (state) => state.errorMessage,
            'errorMessage',
            'Tracking interrupted.',
          )
          .having(
            (state) => state.backgroundTrackingMessage,
            'backgroundTrackingMessage',
            'Background tracking is requested, but location services are currently turned off.',
          ),
    ],
  );

  blocTest<LocationBloc, LocationState>(
    'background permission failures downgrade to foreground tracking when foreground access remains available',
    build: () {
      when(() => repository.bootstrap(recentLimit: 5)).thenAnswer(
        (_) async => TrackingBootstrapSnapshot(
          settings: const TrackingSettings(
            trackingEnabled: true,
            backgroundEnabled: true,
            sampleIntervalSeconds: 60,
            distanceFilterMeters: 10,
          ),
          permissionState: TrackingPermissionState.always,
          recentSamples: <LocationSample>[sample],
          lastKnownSample: sample,
        ),
      );
      when(
        () => repository.startTracking(
          settings: const TrackingSettings(
            trackingEnabled: true,
            backgroundEnabled: true,
            sampleIntervalSeconds: 60,
            distanceFilterMeters: 10,
          ),
          requestPermissions: false,
        ),
      ).thenAnswer(
        (_) async => TrackingStartResult.success(
          TrackingPermissionState.always,
        ),
      );
      when(
        () => repository.startTracking(
          settings: const TrackingSettings(
            trackingEnabled: true,
            backgroundEnabled: false,
            sampleIntervalSeconds: 60,
            distanceFilterMeters: 10,
          ),
          requestPermissions: false,
        ),
      ).thenAnswer(
        (_) async => TrackingStartResult.success(
          TrackingPermissionState.whileInUse,
        ),
      );
      return LocationBloc(repository);
    },
    act: (bloc) async {
      bloc.add(const LocationAppBootstrapped());
      await Future<void>.delayed(Duration.zero);
      failuresController.add(
        const TrackingFailure(
          kind: TrackingFailureKind.backgroundPermissionDenied,
          message:
              'Tracking stopped because all the time location access is no longer available.',
          permissionState: TrackingPermissionState.whileInUse,
        ),
      );
    },
    expect: () => <Matcher>[
      isA<LocationState>()
          .having((state) => state.isLoading, 'isLoading', true),
      isA<LocationState>()
          .having((state) => state.backgroundEnabled, 'backgroundEnabled', true)
          .having(
            (state) => state.effectiveBackgroundEnabled,
            'effectiveBackgroundEnabled',
            true,
          )
          .having((state) => state.currentSample, 'currentSample', sample),
      isA<LocationState>()
          .having((state) => state.isLoading, 'isLoading', false)
          .having((state) => state.trackingEnabled, 'trackingEnabled', true)
          .having(
              (state) => state.backgroundEnabled, 'backgroundEnabled', false)
          .having(
            (state) => state.effectiveBackgroundEnabled,
            'effectiveBackgroundEnabled',
            false,
          )
          .having((state) => state.currentSample, 'currentSample', sample)
          .having(
            (state) => state.recentSamples,
            'recentSamples',
            <LocationSample>[sample],
          )
          .having(
            (state) => state.backgroundTrackingMessage,
            'backgroundTrackingMessage',
            LocationBloc.backgroundPermissionMessage,
          )
          .having((state) => state.errorMessage, 'errorMessage', isNull),
    ],
    verify: (_) {
      verify(
        () => repository.updateTrackingSettings(backgroundEnabled: false),
      ).called(1);
      verify(
        () => repository.startTracking(
          settings: const TrackingSettings(
            trackingEnabled: true,
            backgroundEnabled: false,
            sampleIntervalSeconds: 60,
            distanceFilterMeters: 10,
          ),
          requestPermissions: false,
        ),
      ).called(1);
    },
  );
}
