import 'package:get_it/get_it.dart';
import 'package:location_logger/core/utils/platform_info.dart';
import 'package:location_logger/features/location_tracking/data/repositories/location_repository_impl.dart';
import 'package:location_logger/features/location_tracking/data/services/android_background_service.dart';
import 'package:location_logger/features/location_tracking/data/services/device_location_source.dart';
import 'package:location_logger/features/location_tracking/data/services/notification_coordinator.dart';
import 'package:location_logger/features/location_tracking/data/storage/location_database.dart';
import 'package:location_logger/features/location_tracking/data/storage/tracking_settings_store.dart';
import 'package:location_logger/features/location_tracking/domain/repositories/location_repository.dart';
import 'package:location_logger/features/location_tracking/presentation/bloc/location_bloc.dart';

/// Shared service locator for app-scoped dependencies.
final GetIt getIt = GetIt.instance;

/// Registers the app dependencies used by the location tracking feature.
Future<void> configureDependencies() async {
  if (getIt.isRegistered<LocationRepository>()) {
    return;
  }

  getIt
    ..registerLazySingleton<PlatformInfo>(DefaultPlatformInfo.new)
    ..registerLazySingleton<LocationDatabase>(
      LocationDatabase.new,
      dispose: (database) => database.close(),
    )
    ..registerLazySingleton<TrackingSettingsStore>(TrackingSettingsStore.new)
    ..registerLazySingleton<DeviceLocationSource>(DeviceLocationSource.new)
    ..registerLazySingleton<NotificationCoordinator>(
      () => NotificationCoordinator(platformInfo: getIt<PlatformInfo>()),
    )
    ..registerLazySingleton<AndroidBackgroundServiceManager>(
      () =>
          AndroidBackgroundServiceManager(platformInfo: getIt<PlatformInfo>()),
    )
    ..registerLazySingleton<LocationRepository>(
      () => LocationRepositoryImpl(
        database: getIt<LocationDatabase>(),
        settingsStore: getIt<TrackingSettingsStore>(),
        locationSource: getIt<DeviceLocationSource>(),
        backgroundService: getIt<AndroidBackgroundServiceManager>(),
        notificationCoordinator: getIt<NotificationCoordinator>(),
        platformInfo: getIt<PlatformInfo>(),
      ),
      dispose: (repository) => repository.dispose(),
    )
    ..registerFactory<LocationBloc>(
      () => LocationBloc(getIt<LocationRepository>()),
    );

  await getIt<NotificationCoordinator>().initialize();
  await getIt<AndroidBackgroundServiceManager>().configure();
}
