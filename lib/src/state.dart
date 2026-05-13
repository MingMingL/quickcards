import 'package:flutter/foundation.dart';

import 'models.dart';
import 'repos.dart';

class SettingsModel extends ChangeNotifier {
  SettingsModel({required this.repos});

  final AppRepositories repos;

  AppSettings? _settings;
  AppSettings? get settings => _settings;

  Future<void> load() async {
    _settings = await repos.settings.getSettings();
    notifyListeners();
  }

  Future<void> setDailyGoal(int value) async {
    await repos.settings.setDailyGoal(value);
    await load();
  }

  Future<void> setNewCardsPerDay(int value) async {
    await repos.settings.setNewCardsPerDay(value);
    await load();
  }
}

class DecksModel extends ChangeNotifier {
  DecksModel({required this.repos});

  final AppRepositories repos;

  List<DeckStats> _deckStats = const [];
  List<DeckStats> get deckStats => _deckStats;

  int get globalDueCount => _deckStats.fold(0, (sum, d) => sum + d.dueCards);

  Future<void> refresh() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    _deckStats = await repos.decks.listDeckStats(nowMs: now);
    notifyListeners();
  }
}

class DeckDetailModel extends ChangeNotifier {
  DeckDetailModel({required this.repos, required this.deck});

  final AppRepositories repos;
  final Deck deck;

  List<CardItem> _cards = const [];
  List<CardItem> get cards => _cards;

  String _query = '';
  String get query => _query;

  Future<void> refresh() async {
    _cards = await repos.cards.listCards(deckId: deck.id, query: _query);
    notifyListeners();
  }

  void setQuery(String value) {
    _query = value;
    refresh();
  }

  Future<void> addCard({
    required String front,
    required String back,
    required String? tags,
  }) async {
    await repos.cards.createCard(deckId: deck.id, front: front, back: back, tags: tags);
    await refresh();
  }

  Future<void> updateCard({
    required String cardId,
    required String front,
    required String back,
    required String? tags,
  }) async {
    await repos.cards.updateCard(cardId: cardId, front: front, back: back, tags: tags);
    await refresh();
  }

  Future<void> deleteCard(String cardId) async {
    await repos.cards.deleteCard(cardId);
    await refresh();
  }

  Future<int> importCsv(List<int> bytes) async {
    final count = await repos.cards.importCsv(deckId: deck.id, bytes: bytes);
    await refresh();
    return count;
  }
}

class ReviewSessionModel extends ChangeNotifier {
  ReviewSessionModel({
    required this.repos,
    required this.settings,
    required String? initialDeckId,
  }) : _deckId = initialDeckId;

  final AppRepositories repos;
  final AppSettings settings;

  String? _deckId;
  String? get deckId => _deckId;

  List<Deck> _decks = const [];
  List<Deck> get decks => _decks;

  List<CardItem> _queue = const [];
  List<CardItem> get queue => _queue;

  int _index = 0;
  int get index => _index;

  bool _showAnswer = false;
  bool get showAnswer => _showAnswer;

  int againCount = 0;
  int hardCount = 0;
  int goodCount = 0;
  int easyCount = 0;

  bool get finished => _queue.isNotEmpty && _index >= _queue.length;

  CardItem? get current {
    if (_queue.isEmpty) return null;
    if (_index < 0 || _index >= _queue.length) return null;
    return _queue[_index];
  }

  Future<void> load() async {
    _decks = await repos.decks.listDecks();
    await _loadQueue();
    notifyListeners();
  }

  Future<void> setDeck(String? deckId) async {
    _deckId = deckId;
    await _loadQueue();
    notifyListeners();
  }

  void toggleAnswer() {
    _showAnswer = !_showAnswer;
    notifyListeners();
  }

  Future<void> grade(int grade) async {
    final c = current;
    if (c == null) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await repos.cards.applyReview(card: c, grade: grade, nowMs: nowMs);

    switch (grade) {
      case 1:
        againCount++;
        break;
      case 3:
        hardCount++;
        break;
      case 4:
        goodCount++;
        break;
      case 5:
        easyCount++;
        break;
    }

    _index++;
    _showAnswer = false;
    notifyListeners();
  }

  Future<void> _loadQueue() async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final due = await repos.cards.getDueCards(
      deckId: _deckId,
      nowMs: nowMs,
      limit: settings.dailyGoal,
    );
    final remain = settings.dailyGoal - due.length;
    final remainSafe = remain < 0 ? 0 : remain;
    final newLimit = remainSafe < settings.newCardsPerDay ? remainSafe : settings.newCardsPerDay;
    final newCards = await repos.cards.getNewCards(
      deckId: _deckId,
      limit: newLimit,
    );
    _queue = [...due, ...newCards];
    _index = 0;
    _showAnswer = false;
    againCount = 0;
    hardCount = 0;
    goodCount = 0;
    easyCount = 0;
  }
}

class StatsModel extends ChangeNotifier {
  StatsModel({required this.repos});

  final AppRepositories repos;

  int todayReviews = 0;
  int todayNewCards = 0;
  double todayGoodEasyRate = 0;
  int streakDays = 0;
  List<DayCount> last7Days = const [];

  Future<void> refresh() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final since = todayStart.subtract(const Duration(days: 6));
    final logs = await repos.reviews.getLogsSince(since.millisecondsSinceEpoch);

    final counts = <int, int>{};
    var todayTotal = 0;
    var todayGoodEasy = 0;
    for (final l in logs) {
      final d = DateTime.fromMillisecondsSinceEpoch(l.reviewedAtMs);
      final dayStart = DateTime(d.year, d.month, d.day).millisecondsSinceEpoch;
      counts[dayStart] = (counts[dayStart] ?? 0) + 1;
      if (dayStart == todayStart.millisecondsSinceEpoch) {
        todayTotal++;
        if (l.grade == 4 || l.grade == 5) {
          todayGoodEasy++;
        }
      }
    }

    last7Days = List.generate(7, (i) {
      final day = DateTime(since.year, since.month, since.day)
          .add(Duration(days: i))
          .millisecondsSinceEpoch;
      return DayCount(dayStartMs: day, count: counts[day] ?? 0);
    });

    todayReviews = todayTotal;
    todayGoodEasyRate = todayTotal == 0 ? 0 : todayGoodEasy / todayTotal;

    final todayEnd = todayStart.add(const Duration(days: 1));
    todayNewCards = await repos.cards.countCardsCreatedBetween(
      startMs: todayStart.millisecondsSinceEpoch,
      endMs: todayEnd.millisecondsSinceEpoch,
    );

    streakDays = await _computeStreak(todayStartMs: todayStart.millisecondsSinceEpoch);

    notifyListeners();
  }

  Future<int> _computeStreak({required int todayStartMs}) async {
    final days = await repos.reviews.getDistinctReviewDaysMs();
    if (days.isEmpty) return 0;

    final set = days.toSet();
    var streak = 0;
    var cur = todayStartMs;
    while (set.contains(cur)) {
      streak++;
      cur -= 86400000;
    }
    return streak;
  }
}

class DayCount {
  const DayCount({required this.dayStartMs, required this.count});

  final int dayStartMs;
  final int count;
}
