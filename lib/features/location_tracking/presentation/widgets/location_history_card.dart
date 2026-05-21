import 'package:flutter/material.dart';
import 'package:location_logger/core/utils/date_time_formatter.dart';
import 'package:location_logger/features/location_tracking/domain/entities/location_sample.dart';

/// Card that previews the latest persisted location samples.
class LocationHistoryCard extends StatelessWidget {
  /// Creates the location history card.
  const LocationHistoryCard({
    required this.samples,
    super.key,
  });

  /// Samples to show in the recent history preview.
  final List<LocationSample> samples;

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
              'Recent log preview',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'The latest five samples stay visible here so you can confirm persistence across relaunches.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            if (samples.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F7F2),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Text('No logged samples yet.'),
              )
            else
              Column(
                children: samples
                    .map(
                      (sample) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _HistoryTile(sample: sample),
                      ),
                    )
                    .toList(growable: false),
              ),
          ],
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.sample});

  final LocationSample sample;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateTimeFormatter.asDashboardLabel(sample.capturedAtUtc),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${sample.latitude.toStringAsFixed(6)}, ${sample.longitude.toStringAsFixed(6)}',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Accuracy ${sample.accuracyMeters.toStringAsFixed(1)} m • ${sample.source}',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
