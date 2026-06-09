class MoodBadge {
  final String id;
  final String title;
  final String description;
  final bool unlocked;

  const MoodBadge({
    required this.id,
    required this.title,
    required this.description,
    required this.unlocked,
  });
}

class GamificationService {
  static int currentStreak(List<Map<String, dynamic>> entries) {
    final dates = entries
        .where((entry) => entry['is_deleted'] != 1)
        .map((entry) => DateTime.tryParse(entry['date']?.toString() ?? ''))
        .whereType<DateTime>()
        .map((date) => DateTime(date.year, date.month, date.day))
        .toSet();
    var streak = 0;
    var cursor = DateTime.now();
    cursor = DateTime(cursor.year, cursor.month, cursor.day);
    while (dates.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  static int longestStreak(List<Map<String, dynamic>> entries) {
    final sortedDates = entries
        .where((entry) => entry['is_deleted'] != 1)
        .map((entry) => DateTime.tryParse(entry['date']?.toString() ?? ''))
        .whereType<DateTime>()
        .map((date) => DateTime(date.year, date.month, date.day))
        .toSet()
        .toList()
      ..sort();
    if (sortedDates.isEmpty) return 0;

    var longest = 1;
    var current = 1;
    for (var i = 1; i < sortedDates.length; i++) {
      final diff = sortedDates[i].difference(sortedDates[i - 1]).inDays;
      if (diff == 1) {
        current++;
      } else if (diff > 1) {
        current = 1;
      }
      if (current > longest) longest = current;
    }
    return longest;
  }

  static List<MoodBadge> badges(List<Map<String, dynamic>> entries) {
    final active = entries.where((entry) => entry['is_deleted'] != 1).toList();
    final streak = currentStreak(active);
    final longest = longestStreak(active);
    final positiveRun = _positiveRun(active);
    return [
      MoodBadge(
        id: 'first_entry',
        title: 'First Reflection',
        description: 'Create your first journal entry.',
        unlocked: active.isNotEmpty,
      ),
      MoodBadge(
        id: 'seven_day_streak',
        title: '7-Day Rhythm',
        description: 'Journal for 7 days in a row.',
        unlocked: longest >= 7 || streak >= 7,
      ),
      MoodBadge(
        id: 'thirty_day_streak',
        title: '30-Day Commitment',
        description: 'Complete a 30-day journaling streak.',
        unlocked: longest >= 30 || streak >= 30,
      ),
      MoodBadge(
        id: 'positive_flow',
        title: 'Positive Flow',
        description: 'Keep a positive mood for 3 entries in a row.',
        unlocked: positiveRun >= 3,
      ),
      MoodBadge(
        id: 'deep_reflector',
        title: 'Deep Reflector',
        description: 'Write 20 journal entries.',
        unlocked: active.length >= 20,
      ),
    ];
  }

  static int _positiveRun(List<Map<String, dynamic>> entries) {
    final sorted = [...entries]
      ..sort((a, b) => (b['date']?.toString() ?? '').compareTo(a['date']?.toString() ?? ''));
    var run = 0;
    var best = 0;
    for (final entry in sorted) {
      final mood = entry['mood']?.toString().toLowerCase() ?? '';
      if (mood == 'joy' || mood == 'love' || mood == 'surprise') {
        run++;
        if (run > best) best = run;
      } else {
        run = 0;
      }
    }
    return best;
  }

  static int preferredReminderHour(List<Map<String, dynamic>> entries) {
    final hours = entries
        .map((entry) => DateTime.tryParse(entry['date']?.toString() ?? ''))
        .whereType<DateTime>()
        .map((date) => date.hour)
        .toList();
    if (hours.isEmpty) return 21;
    final counts = <int, int>{};
    for (final hour in hours) {
      counts[hour] = (counts[hour] ?? 0) + 1;
    }
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }
}
