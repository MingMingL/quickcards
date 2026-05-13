import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'db.dart';
import 'models.dart';
import 'srs.dart';

class AppRepositories {
  AppRepositories({required this.db})
      : decks = DeckRepository(db: db.db),
        cards = CardRepository(db: db.db),
        reviews = ReviewRepository(db: db.db),
        settings = SettingsRepository(db: db.db);

  final AppDatabase db;
  final DeckRepository decks;
  final CardRepository cards;
  final ReviewRepository reviews;
  final SettingsRepository settings;
}

class DeckRepository {
  DeckRepository({required this.db});

  final Database db;
  final _uuid = const Uuid();

  Future<String> createDeck({required String name}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = _uuid.v4();
    await db.insert('decks', {
      'id': id,
      'name': name,
      'created_at_ms': now,
      'updated_at_ms': now,
    });
    return id;
  }

  Future<void> renameDeck({required String deckId, required String name}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'decks',
      {'name': name, 'updated_at_ms': now},
      where: 'id = ?',
      whereArgs: [deckId],
    );
  }

  Future<void> deleteDeck(String deckId) async {
    await db.transaction((txn) async {
      await txn.delete('cards', where: 'deck_id = ?', whereArgs: [deckId]);
      await txn.delete('decks', where: 'id = ?', whereArgs: [deckId]);
    });
  }

  Future<List<DeckStats>> listDeckStats({required int nowMs}) async {
    final rows = await db.rawQuery('''
SELECT
  d.id AS id,
  d.name AS name,
  d.created_at_ms AS created_at_ms,
  d.updated_at_ms AS updated_at_ms,
  (SELECT COUNT(*) FROM cards c WHERE c.deck_id = d.id) AS total_cards,
  (
    SELECT COUNT(*) FROM cards c
    WHERE c.deck_id = d.id
      AND (
        (c.repetitions > 0 AND c.due_at_ms <= ?)
        OR c.repetitions = 0
      )
  ) AS due_cards
FROM decks d
ORDER BY d.updated_at_ms DESC
''', [nowMs]);

    return rows
        .map(
          (r) => DeckStats(
            deck: Deck(
              id: r['id'] as String,
              name: r['name'] as String,
              createdAtMs: r['created_at_ms'] as int,
              updatedAtMs: r['updated_at_ms'] as int,
            ),
            totalCards: (r['total_cards'] as int?) ?? 0,
            dueCards: (r['due_cards'] as int?) ?? 0,
          ),
        )
        .toList(growable: false);
  }

  Future<List<Deck>> listDecks() async {
    final rows = await db.query('decks', orderBy: 'updated_at_ms DESC');
    return rows
        .map(
          (r) => Deck(
            id: r['id'] as String,
            name: r['name'] as String,
            createdAtMs: r['created_at_ms'] as int,
            updatedAtMs: r['updated_at_ms'] as int,
          ),
        )
        .toList(growable: false);
  }
}

class CardRepository {
  CardRepository({required this.db});

  final Database db;
  final _uuid = const Uuid();

  Future<String> createCard({
    required String deckId,
    required String front,
    required String back,
    required String? tags,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = _uuid.v4();
    await db.insert('cards', {
      'id': id,
      'deck_id': deckId,
      'front': front,
      'back': back,
      'tags': tags,
      'created_at_ms': now,
      'updated_at_ms': now,
      'due_at_ms': now,
      'interval_days': 0,
      'ease_factor': 2.5,
      'repetitions': 0,
      'last_reviewed_at_ms': null,
    });
    return id;
  }

  Future<void> updateCard({
    required String cardId,
    required String front,
    required String back,
    required String? tags,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'cards',
      {'front': front, 'back': back, 'tags': tags, 'updated_at_ms': now},
      where: 'id = ?',
      whereArgs: [cardId],
    );
  }

  Future<void> deleteCard(String cardId) async {
    await db.delete('cards', where: 'id = ?', whereArgs: [cardId]);
  }

  Future<int> countCardsCreatedBetween({
    required int startMs,
    required int endMs,
  }) async {
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM cards WHERE created_at_ms >= ? AND created_at_ms < ?',
      [startMs, endMs],
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  Future<List<CardItem>> listCards({
    required String deckId,
    String? query,
  }) async {
    final q = query?.trim();
    final where = <String>['deck_id = ?'];
    final args = <Object?>[deckId];
    if (q != null && q.isNotEmpty) {
      where.add('(front LIKE ? OR back LIKE ?)');
      args.addAll(['%$q%', '%$q%']);
    }

    final rows = await db.query(
      'cards',
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: 'updated_at_ms DESC',
    );

    return rows.map(_mapCard).toList(growable: false);
  }

  Future<List<CardItem>> getDueCards({
    required String? deckId,
    required int nowMs,
    required int limit,
  }) async {
    final where = <String>['repetitions > 0', 'due_at_ms <= ?'];
    final args = <Object?>[nowMs];
    if (deckId != null) {
      where.add('deck_id = ?');
      args.add(deckId);
    }
    final rows = await db.query(
      'cards',
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: 'due_at_ms ASC',
      limit: limit,
    );
    return rows.map(_mapCard).toList(growable: false);
  }

  Future<List<CardItem>> getNewCards({
    required String? deckId,
    required int limit,
  }) async {
    final where = <String>['repetitions = 0'];
    final args = <Object?>[];
    if (deckId != null) {
      where.add('deck_id = ?');
      args.add(deckId);
    }
    final rows = await db.query(
      'cards',
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: 'created_at_ms ASC',
      limit: limit,
    );
    return rows.map(_mapCard).toList(growable: false);
  }

  Future<void> applyReview({
    required CardItem card,
    required int grade,
    required int nowMs,
  }) async {
    final res = applySm2(card: card, grade: grade, nowMs: nowMs);
    final logId = _uuid.v4();

    await db.transaction((txn) async {
      await txn.insert('review_logs', {
        'id': logId,
        'card_id': card.id,
        'reviewed_at_ms': nowMs,
        'grade': grade,
      });
      await txn.update(
        'cards',
        {
          'due_at_ms': res.dueAtMs,
          'interval_days': res.intervalDays,
          'ease_factor': res.easeFactor,
          'repetitions': res.repetitions,
          'last_reviewed_at_ms': res.lastReviewedAtMs,
          'updated_at_ms': nowMs,
        },
        where: 'id = ?',
        whereArgs: [card.id],
      );
    });
  }

  Future<int> importCsv({
    required String deckId,
    required List<int> bytes,
  }) async {
    final text = utf8.decode(bytes);
    final rows = const CsvToListConverter(
      eol: '\n',
      shouldParseNumbers: false,
    ).convert(text);
    if (rows.isEmpty) return 0;

    final header = rows.first.map((e) => (e ?? '').toString()).toList();
    if (header.length < 2 ||
        header[0].trim() != 'front' ||
        header[1].trim() != 'back') {
      throw Exception('CSV 表头必须是 front,back,tags');
    }

    var imported = 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.transaction((txn) async {
      for (var i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.isEmpty) continue;
        final front = row[0].toString().trim();
        final back = row.length > 1 ? row[1].toString().trim() : '';
        final tags = row.length > 2 ? row[2].toString().trim() : '';
        if (front.isEmpty || back.isEmpty) continue;
        await txn.insert('cards', {
          'id': _uuid.v4(),
          'deck_id': deckId,
          'front': front,
          'back': back,
          'tags': tags.isEmpty ? null : tags,
          'created_at_ms': now,
          'updated_at_ms': now,
          'due_at_ms': now,
          'interval_days': 0,
          'ease_factor': 2.5,
          'repetitions': 0,
          'last_reviewed_at_ms': null,
        });
        imported++;
      }
    });

    return imported;
  }

  CardItem _mapCard(Map<String, Object?> r) {
    return CardItem(
      id: r['id'] as String,
      deckId: r['deck_id'] as String,
      front: r['front'] as String,
      back: r['back'] as String,
      tags: r['tags'] as String?,
      createdAtMs: r['created_at_ms'] as int,
      updatedAtMs: r['updated_at_ms'] as int,
      dueAtMs: r['due_at_ms'] as int,
      intervalDays: r['interval_days'] as int,
      easeFactor: (r['ease_factor'] as num).toDouble(),
      repetitions: r['repetitions'] as int,
      lastReviewedAtMs: r['last_reviewed_at_ms'] as int?,
    );
  }
}

class ReviewRepository {
  ReviewRepository({required this.db});

  final Database db;

  Future<List<ReviewLog>> getLogsSince(int sinceMs) async {
    final rows = await db.query(
      'review_logs',
      where: 'reviewed_at_ms >= ?',
      whereArgs: [sinceMs],
      orderBy: 'reviewed_at_ms ASC',
    );
    return rows
        .map(
          (r) => ReviewLog(
            id: r['id'] as String,
            cardId: r['card_id'] as String,
            reviewedAtMs: r['reviewed_at_ms'] as int,
            grade: r['grade'] as int,
          ),
        )
        .toList(growable: false);
  }

  Future<List<int>> getDistinctReviewDaysMs() async {
    final rows = await db.rawQuery('''
SELECT DISTINCT (reviewed_at_ms / 86400000) AS day
FROM review_logs
ORDER BY day DESC
''');
    return rows
        .map((r) => (r['day'] as int) * 86400000)
        .toList(growable: false);
  }
}

class SettingsRepository {
  SettingsRepository({required this.db});

  final Database db;

  static const _keyDailyGoal = 'daily_goal';
  static const _keyNewCardsPerDay = 'new_cards_per_day';

  Future<void> ensureDefaults() async {
    final existing = await db.query('settings');
    if (existing.isNotEmpty) return;
    await db.insert('settings', {'key': _keyDailyGoal, 'value': '20'});
    await db.insert('settings', {'key': _keyNewCardsPerDay, 'value': '10'});
  }

  Future<AppSettings> getSettings() async {
    final rows = await db.query('settings');
    final map = <String, String>{};
    for (final r in rows) {
      map[r['key'] as String] = r['value'] as String;
    }

    return AppSettings(
      dailyGoal: int.tryParse(map[_keyDailyGoal] ?? '') ?? 20,
      newCardsPerDay: int.tryParse(map[_keyNewCardsPerDay] ?? '') ?? 10,
    );
  }

  Future<void> setDailyGoal(int value) async {
    await db.insert(
      'settings',
      {'key': _keyDailyGoal, 'value': value.toString()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> setNewCardsPerDay(int value) async {
    await db.insert(
      'settings',
      {'key': _keyNewCardsPerDay, 'value': value.toString()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
