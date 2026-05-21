import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:location_logger/core/di/injection.dart';
import 'package:location_logger/core/theme/app_theme.dart';
import 'package:location_logger/features/location_tracking/presentation/bloc/location_bloc.dart';
import 'package:location_logger/features/location_tracking/presentation/view/location_dashboard_page.dart';

/// Root widget for the location logging demo.
class LocationLoggerApp extends StatelessWidget {
  /// Creates the root application widget.
  const LocationLoggerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<LocationBloc>(
      create: (_) =>
          getIt<LocationBloc>()..add(const LocationAppBootstrapped()),
      child: MaterialApp(
        title: 'Location Logger',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(),
        home: const LocationDashboardPage(),
      ),
    );
  }
}
