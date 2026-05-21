import 'package:flutter/material.dart';
import 'package:location_logger/core/utils/date_time_formatter.dart';
import 'package:location_logger/features/location_tracking/domain/models/tracking_permission_state.dart';
import 'package:location_logger/features/location_tracking/presentation/bloc/location_bloc.dart';

/// Card that summarizes the current location, tracking mode, and status.
class LocationStatusCard extends StatelessWidget {
  /// Creates the location status card.
  const LocationStatusCard({
    required this.state,
    super.key,
  });

  /// Current dashboard state used to render the summary.
  final LocationState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentSample = state.currentSample;
    final trackingModeLabel = _trackingModeLabel();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Icon(
                      Icons.my_location_rounded,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current / last known location',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        state.trackingEnabled
                            ? 'Tracking is currently active.'
                            : 'Tracking is currently stopped.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatusChip(
                  label: 'Permission: ${state.permissionState.label}',
                  color: _permissionColor(theme),
                ),
                if (trackingModeLabel != null)
                  _StatusChip(
                    label: trackingModeLabel,
                    color: theme.colorScheme.secondary,
                  ),
              ],
            ),
            const SizedBox(height: 24),
            _MetricLine(
              label: 'Latitude',
              value: currentSample?.latitude.toStringAsFixed(6) ?? '--',
            ),
            const SizedBox(height: 12),
            _MetricLine(
              label: 'Longitude',
              value: currentSample?.longitude.toStringAsFixed(6) ?? '--',
            ),
            const SizedBox(height: 12),
            _MetricLine(
              label: 'Accuracy',
              value: currentSample == null
                  ? '--'
                  : '${currentSample.accuracyMeters.toStringAsFixed(1)} m',
            ),
            const SizedBox(height: 12),
            _MetricLine(
              label: 'Last updated',
              value: DateTimeFormatter.asDashboardLabel(
                currentSample?.capturedAtUtc,
              ),
            ),
            const SizedBox(height: 12),
            _MetricLine(
              label: 'Sample interval',
              value: '${state.sampleIntervalSeconds} sec',
            ),
            const SizedBox(height: 12),
            _MetricLine(
              label: 'Distance filter',
              value: '${state.distanceFilterMeters} m',
            ),
            if (state.errorMessage != null) ...[
              const SizedBox(height: 20),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0E9),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          state.errorMessage!,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _permissionColor(ThemeData theme) {
    switch (state.permissionState) {
      case TrackingPermissionState.always:
      case TrackingPermissionState.whileInUse:
        return theme.colorScheme.primary;
      case TrackingPermissionState.deniedForever:
      case TrackingPermissionState.denied:
      case TrackingPermissionState.serviceDisabled:
        return const Color(0xFFD95D39);
      case TrackingPermissionState.unknown:
        return theme.colorScheme.onSurfaceVariant;
    }
  }

  String? _trackingModeLabel() {
    if (state.trackingEnabled) {
      return state.effectiveBackgroundEnabled
          ? 'Background tracking'
          : 'Foreground-only tracking';
    }

    if (state.backgroundEnabled) {
      return 'Background on next start';
    }

    return null;
  }
}

class _MetricLine extends StatelessWidget {
  const _MetricLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
