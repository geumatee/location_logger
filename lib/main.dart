import 'package:flutter/material.dart';
import 'package:location_logger/app.dart';
import 'package:location_logger/core/di/injection.dart';

/// Initializes the app-wide dependencies and launches the Flutter tree.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  runApp(const LocationLoggerApp());
}
