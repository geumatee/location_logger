import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:location_logger/features/location_tracking/domain/entities/location_sample.dart';
import 'package:location_logger/features/location_tracking/presentation/bloc/location_bloc.dart';
import 'package:location_logger/features/location_tracking/presentation/view/location_dashboard_page.dart';
import 'package:mocktail/mocktail.dart';

class _MockLocationBloc extends MockBloc<LocationEvent, LocationState>
    implements LocationBloc {}

void main() {
  setUpAll(() {
    registerFallbackValue(const LocationStartRequested());
    registerFallbackValue(const LocationState.initial());
  });

  testWidgets('renders the latest coordinates on the dashboard',
      (tester) async {
    final bloc = _MockLocationBloc();
    final sample = LocationSample(
      latitude: 13.7563,
      longitude: 100.5018,
      accuracyMeters: 4.2,
      capturedAtUtc: DateTime.utc(2026, 5, 20, 2),
      source: 'widget_test',
    );

    when(() => bloc.state).thenReturn(
      const LocationState.initial().copyWith(
        hasLoaded: true,
        trackingEnabled: true,
        currentSample: sample,
        recentSamples: <LocationSample>[sample],
        sampleIntervalSeconds: 60,
        distanceFilterMeters: 10,
      ),
    );
    whenListen(
      bloc,
      Stream<LocationState>.value(
        const LocationState.initial().copyWith(
          hasLoaded: true,
          trackingEnabled: true,
          currentSample: sample,
          recentSamples: <LocationSample>[sample],
          sampleIntervalSeconds: 60,
          distanceFilterMeters: 10,
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<LocationBloc>.value(
          value: bloc,
          child: const LocationDashboardPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Current / last known location'), findsOneWidget);
    expect(find.text('13.756300'), findsOneWidget);
    expect(find.text('100.501800'), findsOneWidget);
    expect(find.text('Sample interval'), findsOneWidget);
    expect(find.text('Distance filter'), findsOneWidget);
  });

  testWidgets(
    'shows the next background mode and runtime errors while keeping the last sample visible',
    (tester) async {
      final bloc = _MockLocationBloc();
      final sample = LocationSample(
        latitude: 13.7563,
        longitude: 100.5018,
        accuracyMeters: 4.2,
        capturedAtUtc: DateTime.utc(2026, 5, 20, 2),
        source: 'widget_test',
      );

      final state = const LocationState.initial().copyWith(
        hasLoaded: true,
        trackingEnabled: false,
        backgroundEnabled: true,
        effectiveBackgroundEnabled: false,
        currentSample: sample,
        recentSamples: <LocationSample>[sample],
        sampleIntervalSeconds: 60,
        distanceFilterMeters: 10,
        errorMessage: 'Tracking interrupted.',
      );

      when(() => bloc.state).thenReturn(state);
      whenListen(
        bloc,
        Stream<LocationState>.value(state),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<LocationBloc>.value(
            value: bloc,
            child: const LocationDashboardPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Background on next start'), findsOneWidget);
      expect(find.text('Foreground-only tracking'), findsNothing);
      expect(find.text('Tracking interrupted.'), findsOneWidget);
      expect(find.text('13.756300'), findsOneWidget);
      expect(find.text('100.501800'), findsOneWidget);
    },
  );

  testWidgets(
    'hides the tracking mode chip when tracking is stopped without background selected',
    (tester) async {
      final bloc = _MockLocationBloc();
      final state = const LocationState.initial().copyWith(
        hasLoaded: true,
        trackingEnabled: false,
        backgroundEnabled: false,
        effectiveBackgroundEnabled: false,
      );

      when(() => bloc.state).thenReturn(state);
      whenListen(
        bloc,
        Stream<LocationState>.value(state),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<LocationBloc>.value(
            value: bloc,
            child: const LocationDashboardPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Background on next start'), findsNothing);
      expect(find.text('Foreground-only tracking'), findsNothing);
      expect(find.text('Background tracking'), findsNothing);
    },
  );
}
