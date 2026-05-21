import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:location_logger/core/utils/platform_info.dart';
import 'package:location_logger/features/location_tracking/data/services/background_service_contract.dart';

/// Owns local-notification setup for Android background tracking.
class NotificationCoordinator {
  /// Creates a notification coordinator.
  NotificationCoordinator({
    required PlatformInfo platformInfo,
    FlutterLocalNotificationsPlugin? plugin,
  })  : _platformInfo = platformInfo,
        _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final PlatformInfo _platformInfo;
  final FlutterLocalNotificationsPlugin _plugin;

  /// Initializes the plugin and Android notification channel if needed.
  Future<void> initialize() async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_bg_service_small'),
      iOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(settings: settings);

    if (!_platformInfo.isAndroid) {
      return;
    }

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        backgroundServiceChannelId,
        backgroundServiceChannelName,
        description: 'Used for ongoing location tracking',
        importance: Importance.low,
      ),
    );
  }

  /// Requests Android notification permission when the platform requires it.
  Future<void> requestPermissionIfNeeded() async {
    if (!_platformInfo.isAndroid) {
      return;
    }

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
  }
}
