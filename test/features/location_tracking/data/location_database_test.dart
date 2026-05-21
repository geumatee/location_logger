import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:location_logger/features/location_tracking/data/storage/location_database.dart';
import 'package:location_logger/features/location_tracking/domain/entities/location_sample.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Directory tempDirectory;
  late LocationDatabase database;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'location_logger_database_test',
    );
    database = LocationDatabase(
      databaseFactory: databaseFactoryFfi,
      databasePathResolver: () async => p.join(tempDirectory.path, 'test.db'),
    );
  });

  tearDown(() async {
    await database.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('writes and reads recent samples in descending timestamp order',
      () async {
    await database.insertSample(
      LocationSample(
        latitude: 35.0,
        longitude: 139.0,
        accuracyMeters: 10,
        capturedAtUtc: DateTime.utc(2026, 5, 20, 0, 0, 1),
        source: 'test',
      ),
    );
    await database.insertSample(
      LocationSample(
        latitude: 35.1,
        longitude: 139.1,
        accuracyMeters: 9,
        capturedAtUtc: DateTime.utc(2026, 5, 20, 0, 0, 2),
        source: 'test',
      ),
    );

    final samples = await database.fetchRecentSamples(limit: 5);

    expect(samples, hasLength(2));
    expect(samples.first.latitude, 35.1);
    expect(samples.first.longitude, 139.1);
    expect(samples.last.latitude, 35.0);
  });
}
