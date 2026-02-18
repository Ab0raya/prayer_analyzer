enum Pose { qayyam, ruku, sujud, tashahhud, unknown }

class PrayerStep {
  final Pose pose;
  final Duration timestamp;
  final double confidence;

  PrayerStep({
    required this.pose,
    required this.timestamp,
    required this.confidence,
  });
}

class PrayerMistake {
  final String description;
  final Duration timestamp;

  PrayerMistake({required this.description, required this.timestamp});
}

class AnalysisReport {
  final int totalRakahs;
  final bool isComplete;
  final List<PrayerMistake> mistakes;
  final List<PrayerStep> steps;

  AnalysisReport({
    required this.totalRakahs,
    required this.isComplete,
    required this.mistakes,
    required this.steps,
  });

  factory AnalysisReport.empty() {
    return AnalysisReport(
      totalRakahs: 0,
      isComplete: false,
      mistakes: [],
      steps: [],
    );
  }
}
