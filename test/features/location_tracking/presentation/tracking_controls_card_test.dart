import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_logger/features/location_tracking/domain/models/tracking_permission_state.dart';
import 'package:location_logger/features/location_tracking/presentation/bloc/location_bloc.dart';
import 'package:location_logger/features/location_tracking/presentation/widgets/tracking_controls_card.dart';

void main() {
  Widget buildSubject({required bool isIos}) {
    return MaterialApp(
      home: Scaffold(
        body: TrackingControlsCard(
          state: const LocationState.initial(),
          isIos: isIos,
          onBackgroundToggled: (_) {},
          onSampleIntervalChanged: (_) {},
          onDistanceFilterChanged: (_) {},
          onStartPressed: () {},
          onStopPressed: () {},
          onOpenAppSettings: () {},
          onOpenLocationSettings: () {},
        ),
      ),
    );
  }

  testWidgets('shows a single Settings app button on iOS', (tester) async {
    await tester.pumpWidget(buildSubject(isIos: true));

    expect(find.text('Sample interval'), findsNothing);
    expect(find.text('Distance filter'), findsOneWidget);
    expect(find.text('Open Settings app'), findsOneWidget);
    expect(find.text('Open location settings'), findsNothing);
    expect(find.text('Open app settings'), findsNothing);
  });

  testWidgets('keeps separate settings buttons on Android', (tester) async {
    await tester.pumpWidget(buildSubject(isIos: false));

    expect(find.text('Sample interval'), findsOneWidget);
    expect(find.text('Distance filter'), findsOneWidget);
    expect(find.text('Open location settings'), findsOneWidget);
    expect(find.text('Open app settings'), findsOneWidget);
    expect(find.text('Open Settings app'), findsNothing);
  });

  testWidgets(
    'keeps the requested background switch on during transient unavailability',
    (tester) async {
      const transientMessage =
          'Background tracking is requested, but location services are currently turned off.';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TrackingControlsCard(
              state: const LocationState.initial().copyWith(
                backgroundEnabled: true,
                effectiveBackgroundEnabled: false,
                permissionState: TrackingPermissionState.serviceDisabled,
                backgroundTrackingMessage: transientMessage,
              ),
              isIos: false,
              onBackgroundToggled: (_) {},
              onSampleIntervalChanged: (_) {},
              onDistanceFilterChanged: (_) {},
              onStartPressed: () {},
              onStopPressed: () {},
              onOpenAppSettings: () {},
              onOpenLocationSettings: () {},
            ),
          ),
        ),
      );

      expect(find.text(transientMessage), findsOneWidget);

      final switchTile = tester.widget<SwitchListTile>(
        find.byType(SwitchListTile),
      );
      expect(switchTile.onChanged, isNotNull);
      expect(switchTile.value, isTrue);
      expect(
        find.text(
          'Background tracking is requested, but the app is currently limited to foreground-only behavior.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'shows the background permission message and disables the switch after a true downgrade',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TrackingControlsCard(
              state: const LocationState.initial().copyWith(
                isBackgroundToggleLocked: true,
                backgroundTrackingMessage:
                    LocationBloc.backgroundPermissionMessage,
              ),
              isIos: false,
              onBackgroundToggled: (_) {},
              onSampleIntervalChanged: (_) {},
              onDistanceFilterChanged: (_) {},
              onStartPressed: () {},
              onStopPressed: () {},
              onOpenAppSettings: () {},
              onOpenLocationSettings: () {},
            ),
          ),
        ),
      );

      expect(
        find.text(LocationBloc.backgroundPermissionMessage),
        findsOneWidget,
      );

      final switchTile = tester.widget<SwitchListTile>(
        find.byType(SwitchListTile),
      );
      expect(switchTile.onChanged, isNull);
      expect(switchTile.value, isFalse);
    },
  );
}
