import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:location_logger/features/location_tracking/domain/entities/location_sample.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

/// SQLite persistence layer for captured location samples.
class LocationDatabase {
  /// Creates a location database.
  LocationDatabase({
    sqflite.DatabaseFactory? databaseFactory,
    Future<String> Function()? databasePathResolver,
  })  : _databaseFactory = databaseFactory ?? sqflite.databaseFactory,
        _databasePathResolver =
            databasePathResolver ?? _defaultDatabasePathResolver;

  static const String _tableName = 'location_logs';
  static const String _databaseName = 'location_logger.db';

  final sqflite.DatabaseFactory _databaseFactory;
  final Future<String> Function() _databasePathResolver;

  sqflite.Database? _database;

  /// Lazily opens the database and creates the schema on first use.
  Future<sqflite.Database> get database async {
    if (_database != null) {
      return _database!;
    }

    final path = await _databasePathResolver();
    _database = await _databaseFactory.openDatabase(
      path,
      options: sqflite.OpenDatabaseOptions(
        version: 1,
        onCreate: (database, _) async {
          await database.execute('''
            CREATE TABLE $_tableName (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              latitude REAL NOT NULL,
              longitude REAL NOT NULL,
              accuracy_meters REAL NOT NULL,
              captured_at_utc TEXT NOT NULL,
              source TEXT NOT NULL
            )
          ''');
        },
      ),
    );
    return _database!;
  }

  /// Inserts a sample and returns the persisted version with its database id.
  Future<LocationSample> insertSample(LocationSample sample) async {
    final db = await database;
    final id = await db.insert(_tableName, sample.toDatabaseMap());
    return sample.copyWith(id: id);
  }

  /// Fetches the most recent samples in descending timestamp order.
  Future<List<LocationSample>> fetchRecentSamples({int limit = 5}) async {
    final db = await database;
    final rows = await db.query(
      _tableName,
      orderBy: 'captured_at_utc DESC',
      limit: limit,
    );
    return rows
        .map((row) => LocationSample.fromDatabaseMap(row))
        .toList(growable: false);
  }

  /// Closes the database if it is open.
  Future<void> close() async {
    final db = _database;
    if (db == null) {
      return;
    }
    await db.close();
    _database = null;
  }

  static Future<String> _defaultDatabasePathResolver() async {
    final directory = await getApplicationSupportDirectory();
    return p.join(directory.path, _databaseName);
  }
}
