class EncryptedJournal {
  final String ciphertext;
  final String iv;
  final int keyVersion;

  const EncryptedJournal({
    required this.ciphertext,
    required this.iv,
    this.keyVersion = 1,
  });

  Map<String, dynamic> toJson() => {
        'ciphertext': ciphertext,
        'iv': iv,
        'key_version': keyVersion,
      };
}

class TriggerInsight {
  final String category;
  final List<String> words;

  const TriggerInsight({required this.category, required this.words});

  factory TriggerInsight.fromJson(Map<String, dynamic> json) {
    return TriggerInsight(
      category: json['category']?.toString() ?? 'general',
      words: (json['words'] as List? ?? const []).map((e) => e.toString()).toList(),
    );
  }
}

class EmotionRank {
  final String emotion;
  final double confidence;
  final double confidencePercent;

  const EmotionRank({
    required this.emotion,
    required this.confidence,
    required this.confidencePercent,
  });

  factory EmotionRank.fromJson(Map<String, dynamic> json) {
    final confidence = (json['confidence'] as num?)?.toDouble() ?? 0;
    return EmotionRank(
      emotion: json['emotion']?.toString() ?? 'neutral',
      confidence: confidence,
      confidencePercent: (json['confidence_percent'] as num?)?.toDouble() ?? confidence * 100,
    );
  }
}

class CopingPlan {
  final String title;
  final String message;
  final String exercise;
  final List<String> steps;

  const CopingPlan({
    required this.title,
    required this.message,
    required this.exercise,
    required this.steps,
  });

  factory CopingPlan.fromJson(Map<String, dynamic> json) {
    return CopingPlan(
      title: json['title']?.toString() ?? 'Gentle check-in',
      message: json['message']?.toString() ?? 'Take one minute to notice your breath.',
      exercise: json['exercise']?.toString() ?? 'breathing_4_4_6',
      steps: (json['steps'] as List? ?? const []).map((e) => e.toString()).toList(),
    );
  }
}

class JournalAnalysis {
  final String journalId;
  final String primaryEmotion;
  final double confidence;
  final double confidencePercent;
  final Map<String, double> scores;
  final List<EmotionRank> topEmotions;
  final List<TriggerInsight> triggers;
  final Map<String, dynamic> sentimentShift;
  final CopingPlan? copingPlan;
  final bool crisisFlag;
  final String? crisisSignal;
  final int currentStreak;

  const JournalAnalysis({
    required this.journalId,
    required this.primaryEmotion,
    required this.confidence,
    required this.confidencePercent,
    required this.scores,
    required this.topEmotions,
    required this.triggers,
    required this.sentimentShift,
    this.copingPlan,
    required this.crisisFlag,
    required this.currentStreak,
    this.crisisSignal,
  });

  factory JournalAnalysis.fromJson(Map<String, dynamic> json) {
    final rawScores = Map<String, dynamic>.from(json['scores'] ?? const {});
    final streak = Map<String, dynamic>.from(json['streak'] ?? const {});
    return JournalAnalysis(
      journalId: json['journal_id']?.toString() ?? '',
      primaryEmotion: json['primary_emotion']?.toString() ?? 'joy',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      confidencePercent: (json['confidence_percent'] as num?)?.toDouble() ??
          ((json['confidence'] as num?)?.toDouble() ?? 0) * 100,
      scores: rawScores.map((key, value) => MapEntry(key, (value as num).toDouble())),
      topEmotions: (json['top_emotions'] as List? ?? const [])
          .map((e) => EmotionRank.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      triggers: (json['triggers'] as List? ?? const [])
          .map((e) => TriggerInsight.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      sentimentShift: Map<String, dynamic>.from(json['sentiment_shift'] ?? const {}),
      copingPlan: json['coping_plan'] is Map
          ? CopingPlan.fromJson(Map<String, dynamic>.from(json['coping_plan']))
          : null,
      crisisFlag: json['crisis_flag'] == true,
      crisisSignal: json['crisis_signal']?.toString(),
      currentStreak: (streak['current'] as num?)?.toInt() ?? 0,
    );
  }
}
