import 'models.dart';

class SrsResult {
  const SrsResult({
    required this.dueAtMs,
    required this.intervalDays,
    required this.easeFactor,
    required this.repetitions,
    required this.lastReviewedAtMs,
  });

  final int dueAtMs;
  final int intervalDays;
  final double easeFactor;
  final int repetitions;
  final int lastReviewedAtMs;
}

SrsResult applySm2({
  required CardItem card,
  required int grade,
  required int nowMs,
}) {
  final q = _qualityFromGrade(grade);
  var ef = card.easeFactor;
  var reps = card.repetitions;
  var interval = card.intervalDays;

  if (q < 3) {
    reps = 0;
    interval = 1;
  } else {
    reps = reps + 1;
    if (reps == 1) {
      interval = 1;
    } else if (reps == 2) {
      interval = 3;
    } else {
      interval = (interval * ef).round().clamp(1, 36500);
    }
  }

  ef = (ef + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02))).clamp(1.3, 3.0);

  final dueAtMs = DateTime.fromMillisecondsSinceEpoch(nowMs)
      .add(Duration(days: interval))
      .millisecondsSinceEpoch;

  return SrsResult(
    dueAtMs: dueAtMs,
    intervalDays: interval,
    easeFactor: ef,
    repetitions: reps,
    lastReviewedAtMs: nowMs,
  );
}

int _qualityFromGrade(int grade) {
  switch (grade) {
    case 1:
      return 1;
    case 3:
      return 3;
    case 4:
      return 4;
    case 5:
      return 5;
    default:
      return 4;
  }
}

