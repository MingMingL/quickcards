import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._(this.db);

  final Database db;

  static const _dbName = 'quickcards.db';
  static const _dbVersion = 1;

  static Future<AppDatabase> open() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, _dbName);
    final db = await openDatabase(
      dbPath,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
CREATE TABLE decks (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  created_at_ms INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL
)''');

        await db.execute('''
CREATE TABLE cards (
  id TEXT PRIMARY KEY,
  deck_id TEXT NOT NULL,
  front TEXT NOT NULL,
  back TEXT NOT NULL,
  tags TEXT,
  created_at_ms INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL,
  due_at_ms INTEGER NOT NULL,
  interval_days INTEGER NOT NULL,
  ease_factor REAL NOT NULL,
  repetitions INTEGER NOT NULL,
  last_reviewed_at_ms INTEGER
)''');

        await db.execute('CREATE INDEX idx_cards_deck_id ON cards(deck_id)');
        await db.execute('CREATE INDEX idx_cards_due ON cards(due_at_ms)');

        await db.execute('''
CREATE TABLE review_logs (
  id TEXT PRIMARY KEY,
  card_id TEXT NOT NULL,
  reviewed_at_ms INTEGER NOT NULL,
  grade INTEGER NOT NULL
)''');

        await db.execute(
          'CREATE INDEX idx_review_logs_reviewed_at ON review_logs(reviewed_at_ms)',
        );

        await db.execute('''
CREATE TABLE settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
)''');
      },
    );

    return AppDatabase._(db);
  }
}

