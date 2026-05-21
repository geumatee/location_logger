import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:location_logger/features/location_tracking/presentation/bloc/location_bloc.dart';
import 'package:location_logger/features/location_tracking/presentation/widgets/location_history_card.dart';
import 'package:location_logger/features/location_tracking/presentation/widgets/location_status_card.dart';
import 'package:location_logger/features/location_tracking/presentation/widgets/tracking_controls_card.dart';

/// Main dashboard surface for the location tracking demo.
class LocationDashboardPage extends StatefulWidget {
  /// Creates the location dashboard page.
  const LocationDashboardPage({super.key});

  @override
  State<LocationDashboardPage> createState() => _LocationDashboardPageState();
}

class _LocationDashboardPageState extends State<LocationDashboardPage> {
  late final AppLifecycleListener _appLifecycleListener;

  @override
  void initState() {
    super.initState();
    _appLifecycleListener = AppLifecycleListener(
      onResume: () {
        if (!mounted) {
          return;
        }
        context
            .read<LocationBloc>()
            .add(const LocationStatusRefreshRequested());
      },
    );
  }

  @override
  void dispose() {
    _appLifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE6F2EE),
              Color(0xFFF5F6F0),
              Color(0xFFF9EEE1),
            ],
          ),
        ),
        child: SafeArea(
          child: BlocBuilder<LocationBloc, LocationState>(
            builder: (context, state) {
              if (!state.hasLoaded && state.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  const _PageHeader(),
                  const SizedBox(height: 20),
                  LocationStatusCard(state: state),
                  const SizedBox(height: 16),
                  TrackingControlsCard(
                    state: state,
                    isIos: defaultTargetPlatform == TargetPlatform.iOS,
                    onBackgroundToggled: (enabled) {
                      context
                          .read<LocationBloc>()
                          .add(BackgroundTrackingToggled(enabled));
                    },
                    onSampleIntervalChanged: (seconds) {
                      context
                          .read<LocationBloc>()
                          .add(SampleIntervalChanged(seconds));
                    },
                    onDistanceFilterChanged: (meters) {
                      context
                          .read<LocationBloc>()
                          .add(DistanceFilterChanged(meters));
                    },
                    onStartPressed: () {
                      context
                          .read<LocationBloc>()
                          .add(const LocationStartRequested());
                    },
                    onStopPressed: () {
                      context
                          .read<LocationBloc>()
                          .add(const LocationStopRequested());
                    },
                    onOpenAppSettings: () {
                      context
                          .read<LocationBloc>()
                          .add(const OpenAppSettingsRequested());
                    },
                    onOpenLocationSettings: () {
                      context
                          .read<LocationBloc>()
                          .add(const OpenLocationSettingsRequested());
                    },
                  ),
                  const SizedBox(height: 16),
                  LocationHistoryCard(samples: state.recentSamples),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            'Location Logger',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Foreground, background, and Android service tracking in one simple dashboard.',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'The storage and state layers are already structured so a future map screen can subscribe to the same location history.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
