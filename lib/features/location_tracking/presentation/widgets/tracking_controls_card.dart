import 'package:flutter/material.dart';
import 'package:location_logger/features/location_tracking/domain/models/tracking_permission_state.dart';
import 'package:location_logger/features/location_tracking/presentation/bloc/location_bloc.dart';

/// Card that lets the user change tracking settings and start or stop logging.
class TrackingControlsCard extends StatelessWidget {
  static const List<int> _sampleIntervalOptions = <int>[
    3,
    5,
    10,
    30,
    60,
    120,
    300
  ];
  static const List<int> _distanceFilterOptions = <int>[5, 10, 25, 50, 100];

  /// Creates the tracking controls card.
  const TrackingControlsCard({
    required this.state,
    required this.isIos,
    required this.onBackgroundToggled,
    required this.onSampleIntervalChanged,
    required this.onDistanceFilterChanged,
    required this.onStartPressed,
    required this.onStopPressed,
    required this.onOpenAppSettings,
    required this.onOpenLocationSettings,
    super.key,
  });

  /// Current dashboard state that drives the control values.
  final LocationState state;

  /// Whether the app is currently running on iOS.
  final bool isIos;

  /// Called when the background tracking switch changes.
  final ValueChanged<bool> onBackgroundToggled;

  /// Called when the sample interval changes.
  final ValueChanged<int> onSampleIntervalChanged;

  /// Called when the distance filter changes.
  final ValueChanged<int> onDistanceFilterChanged;

  /// Called when the user presses Start.
  final VoidCallback onStartPressed;

  /// Called when the user presses Stop.
  final VoidCallback onStopPressed;

  /// Called when the user wants to open the app settings.
  final VoidCallback onOpenAppSettings;

  /// Called when the user wants to open the device location settings.
  final VoidCallback onOpenLocationSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tracking controls',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Use the switch below to test background behavior. Start tracking after changing permissions or modes.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            SwitchListTile.adaptive(
              value: state.backgroundEnabled,
              onChanged: state.isLoading || state.isBackgroundToggleLocked
                  ? null
                  : onBackgroundToggled,
              contentPadding: EdgeInsets.zero,
              title: const Text('Enable background tracking'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _backgroundSummaryText(),
                  ),
                  if (state.backgroundTrackingMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      state.backgroundTrackingMessage!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (isIos)
              _TrackingSettingDropdown(
                labelText: 'Distance filter',
                suffixText: 'm',
                value: state.distanceFilterMeters,
                options: _distanceFilterOptions,
                enabled: !state.isLoading,
                onChanged: onDistanceFilterChanged,
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _TrackingSettingDropdown(
                      labelText: 'Sample interval',
                      suffixText: 'sec',
                      value: state.sampleIntervalSeconds,
                      options: _sampleIntervalOptions,
                      enabled: !state.isLoading,
                      onChanged: onSampleIntervalChanged,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TrackingSettingDropdown(
                      labelText: 'Distance filter',
                      suffixText: 'm',
                      value: state.distanceFilterMeters,
                      options: _distanceFilterOptions,
                      enabled: !state.isLoading,
                      onChanged: onDistanceFilterChanged,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 8),
            Text(
              isIos
                  ? 'Changes are saved immediately. If tracking is active, the stream restarts with the new distance filter.'
                  : 'Changes are saved immediately. If tracking is active, the stream restarts with the new interval and distance filter.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: state.canStart ? onStartPressed : null,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_arrow_rounded),
                        SizedBox(width: 8),
                        Text('Start'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: state.canStop ? onStopPressed : null,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.stop_circle_outlined),
                        SizedBox(width: 8),
                        Text('Stop'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (isIos)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onOpenAppSettings,
                  icon: const Icon(Icons.settings_outlined),
                  label: const Text('Open Settings app'),
                ),
              )
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  TextButton.icon(
                    onPressed: onOpenLocationSettings,
                    icon: const Icon(Icons.gps_fixed_rounded),
                    label: const Text('Open location settings'),
                  ),
                  TextButton.icon(
                    onPressed: onOpenAppSettings,
                    icon: const Icon(Icons.settings_outlined),
                    label: const Text('Open app settings'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _backgroundSummaryText() {
    if (!state.backgroundEnabled) {
      return 'Tracking stays in the active app session only.';
    }

    if (state.effectiveBackgroundEnabled) {
      return 'Android will use a foreground service. iOS will keep tracking in background while the app stays alive.';
    }

    if (state.permissionState.isTransientlyUnavailable) {
      return 'Background tracking is requested, but the app is currently limited to foreground-only behavior.';
    }

    return 'Background-capable tracking will be used the next time tracking runs.';
  }
}

class _TrackingSettingDropdown extends StatelessWidget {
  const _TrackingSettingDropdown({
    required this.labelText,
    required this.suffixText,
    required this.value,
    required this.options,
    required this.enabled,
    required this.onChanged,
  });

  final String labelText;
  final String suffixText;
  final int value;
  final List<int> options;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: labelText,
        suffixText: suffixText,
      ),
      items: options
          .map(
            (option) => DropdownMenuItem<int>(
              value: option,
              child: Text('$option'),
            ),
          )
          .toList(),
      onChanged: enabled
          ? (selectedValue) {
              if (selectedValue != null && selectedValue != value) {
                onChanged(selectedValue);
              }
            }
          : null,
    );
  }
}
