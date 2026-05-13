import 'package:flutter/foundation.dart';

@immutable
class Deck {
  const Deck({
    required this.id,
    required this.name,
    required this.createdAtMs,
    required this.updatedAtMs,
  });

  final String id;
  final String name;
  final int createdAtMs;
  final int updatedAtMs;

  Deck copyWith({String? name, int? updatedAtMs}) {
    return Deck(
      id: id,
      name: name ?? this.name,
      createdAtMs: createdAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    );
  }
}

@immutable
class CardItem {
  const CardItem({
    required this.id,
    required this.deckId,
    required this.front,
    required this.back,
    required this.tags,
    required this.createdAtMs,
    required this.updatedAtMs,
    required this.dueAtMs,
    required this.intervalDays,
    required this.easeFactor,
    required this.repetitions,
    required this.lastReviewedAtMs,
  });

  final String id;
  final String deckId;
  final String front;
  final String back;
  final String? tags;
  final int createdAtMs;
  final int updatedAtMs;
  final int dueAtMs;
  final int intervalDays;
  final double easeFactor;
  final int repetitions;
  final int? lastReviewedAtMs;

  bool get isNew => repetitions == 0;
}

@immutable
class ReviewLog {
  const ReviewLog({
    required this.id,
    required this.cardId,
    required this.reviewedAtMs,
    required this.grade,
  });

  final String id;
  final String cardId;
  final int reviewedAtMs;
  final int grade;
}

@immutable
class DeckStats {
  const DeckStats({
    required this.deck,
    required this.totalCards,
    required this.dueCards,
  });

  final Deck deck;
  final int totalCards;
  final int dueCards;
}

@immutable
class AppSettings {
  const AppSettings({
    required this.dailyGoal,
    required this.newCardsPerDay,
  });

  final int dailyGoal;
  final int newCardsPerDay;
}

