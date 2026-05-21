/// Android notification channel id used by the background service.
const String backgroundServiceChannelId = 'location_logger_tracking';

/// Android notification channel name used by the background service.
const String backgroundServiceChannelName = 'Location tracking';

/// Foreground notification id used while Android tracking is active.
const int backgroundServiceNotificationId = 24107;

/// Service event emitted when a new sample is available.
const String backgroundServiceLocationUpdatedEvent = 'location.updated';

/// Service event used to (re)start tracking with the latest settings.
const String backgroundServiceSyncEvent = 'tracking.sync';

/// Service event used to stop tracking explicitly.
const String backgroundServiceStopEvent = 'tracking.stop';

/// Service event emitted when background tracking fails.
const String backgroundServiceErrorEvent = 'tracking.error';
