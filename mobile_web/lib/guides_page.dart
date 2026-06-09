import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'db_helper.dart';
import 'theme/nuromood_ui.dart';

class GuidesPage extends StatefulWidget {
  const GuidesPage({super.key, required this.userId});

  final int userId;

  @override
  State<GuidesPage> createState() => _GuidesPageState();
}

class _GuidesPageState extends State<GuidesPage> {
  final DBHelper _dbHelper = DBHelper();
  List<Map<String, dynamic>> _entries = [];
  bool _isLoading = true;

  final Map<String, List<Map<String, dynamic>>> guidesByCategory = const {
    "Mind & Gratitude": [
      {
        "title": "Catch a Pleasant Event Daily",
        "author": "Daily Practice",
        "description":
            "Reflect on one positive moment from today. Notice what happened, how it felt, and what helped it happen.",
        "image": "assets/images/mind1.png",
        "icon": Icons.wb_sunny_rounded,
        "minutes": "3 min",
      },
      {
        "title": "Mindful Breathing",
        "author": "Calm Reset",
        "description":
            "Use a short breathing cycle to settle your body before writing or sleeping.",
        "image": "assets/images/mind2.png",
        "icon": Icons.air_rounded,
        "minutes": "5 min",
      },
      {
        "title": "Gratitude Journal",
        "author": "Reflection",
        "description":
            "Write three things you appreciate today, even if they are small.",
        "image": "assets/images/mind3.png",
        "icon": Icons.favorite_rounded,
        "minutes": "4 min",
      },
    ],
    "Personal Growth": [
      {
        "title": "Navigating Big Change",
        "author": "Reboot Coaching",
        "description":
            "Name the transition, choose one small next step, and reduce pressure by focusing on today.",
        "image": "assets/images/growth1.png",
        "icon": Icons.route_rounded,
        "minutes": "6 min",
      },
      {
        "title": "Turn Setbacks Into Learning",
        "author": "Resilience",
        "description":
            "Separate what happened from what it means, then write one lesson you can carry forward.",
        "image": "assets/images/growth2.png",
        "icon": Icons.auto_graph_rounded,
        "minutes": "5 min",
      },
      {
        "title": "Set SMART Goals",
        "author": "Goal Builder",
        "description":
            "Shape vague hopes into specific, measurable, achievable, relevant, and time-bound actions.",
        "image": "assets/images/growth3.png",
        "icon": Icons.flag_rounded,
        "minutes": "7 min",
      },
    ],
    "Health & Wellness": [
      {
        "title": "Morning Stretch Routine",
        "author": "Body Check-in",
        "description":
            "Begin with gentle movement to reduce tension and notice how your body feels.",
        "image": "assets/images/health1.png",
        "icon": Icons.self_improvement_rounded,
        "minutes": "5 min",
      },
      {
        "title": "Balanced Eating Habits",
        "author": "Nutrition Basics",
        "description":
            "Look for simple patterns: hydration, balanced meals, and food that supports energy.",
        "image": "assets/images/health2.png",
        "icon": Icons.restaurant_rounded,
        "minutes": "4 min",
      },
      {
        "title": "Mindful Sleep",
        "author": "Night Routine",
        "description":
            "Create a slower evening rhythm with less screen time and a short reflection.",
        "image": "assets/images/health3.png",
        "icon": Icons.nightlight_round,
        "minutes": "6 min",
      },
    ],
  };

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    final entries = await _dbHelper.getJournals(widget.userId);
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _isLoading = false;
    });
  }

  void _showArticle(BuildContext context, Map<String, dynamic> guide) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _GuideDetailPage(guide: guide)),
    );
  }

  List<Map<String, dynamic>> _weeklyMoodData() {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day)
        .subtract(Duration(days: today.weekday - 1));
    final days = List.generate(7, (index) => start.add(Duration(days: index)));
    final labels = const ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

    return List.generate(7, (index) {
      final day = days[index];
      final dayEntries = _entries.where((entry) {
        final date = DateTime.tryParse(entry['date']?.toString() ?? '');
        if (date == null) return false;
        return date.year == day.year &&
            date.month == day.month &&
            date.day == day.day &&
            entry['is_deleted'] != 1;
      }).toList();

      final score = dayEntries.isEmpty
          ? 0.0
          : dayEntries
                  .map((entry) =>
                      _moodScore(entry['mood']?.toString() ?? 'neutral'))
                  .reduce((a, b) => a + b) /
              dayEntries.length;
      return {
        "day": labels[index],
        "mood": score,
        "count": dayEntries.length,
      };
    });
  }

  double _moodScore(String mood) {
    switch (mood.toLowerCase()) {
      case 'joy':
      case 'love':
      case 'surprise':
        return 5;
      case 'neutral':
        return 3;
      case 'anxiety':
      case 'fear':
        return 2;
      case 'sadness':
      case 'anger':
        return 1;
      default:
        return 3;
    }
  }

  Color _moodColor(BuildContext context, double mood) {
    if (mood >= 4) return NeuroColors.teal;
    if (mood >= 3) return const Color(0xFFFFC857);
    if (mood <= 0) {
      return Theme.of(context).brightness == Brightness.dark
          ? Colors.white38
          : NeuroColors.muted.withValues(alpha: 0.42);
    }
    return NeuroColors.electricPink;
  }

  Widget _buildDailyMoodChart(BuildContext context) {
    final theme = Theme.of(context);
    final compact = MediaQuery.of(context).size.width < NeuroBreakpoints.mobile;
    final todayIndex = DateTime.now().weekday - 1;
    final weeklyMoods = _weeklyMoodData();
    final activeDays =
        weeklyMoods.where((e) => (e["count"] as int) > 0).toList();
    final avgMood = activeDays.isEmpty
        ? 0.0
        : activeDays.map((e) => e["mood"] as double).reduce((a, b) => a + b) /
            activeDays.length;

    return NeuroCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const NeuroSectionLabel(
                  text: "Weekly Signal", icon: Icons.monitor_heart),
              const Spacer(),
              Chip(
                avatar: const Icon(Icons.show_chart, size: 16),
                label: Text(activeDays.isEmpty
                    ? "No data yet"
                    : "Avg ${avgMood.toStringAsFixed(1)}"),
              ),
            ],
          ),
          if (activeDays.isEmpty) ...[
            const SizedBox(height: 10),
            Text(
              "Write a journal entry this week to make this chart reflect your real mood pattern.",
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            height: compact ? 176 : 210,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: 5,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: theme.colorScheme.primary.withValues(alpha: 0.10),
                    strokeWidth: 1,
                  ),
                  getDrawingVerticalLine: (_) => FlLine(
                    color: theme.colorScheme.primary.withValues(alpha: 0.08),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: theme.textTheme.labelSmall,
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < weeklyMoods.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              weeklyMoods[index]["day"],
                              style: theme.textTheme.labelSmall,
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(
                      weeklyMoods.length,
                      (index) => FlSpot(
                        index.toDouble(),
                        weeklyMoods[index]["mood"] as double,
                      ),
                    ),
                    isCurved: true,
                    color: NeuroColors.teal,
                    barWidth: 3,
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          NeuroColors.teal.withValues(alpha: 0.24),
                          NeuroColors.electricPink.withValues(alpha: 0.04),
                        ],
                      ),
                    ),
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        final moodValue =
                            weeklyMoods[index.toInt()]["mood"] as double;
                        final color = index == todayIndex
                            ? NeuroColors.electricPink
                            : _moodColor(context, moodValue);
                        return FlDotCirclePainter(
                          color: color,
                          radius: index == todayIndex ? 6 : 4.5,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                  ),
                ],
                extraLinesData: ExtraLinesData(horizontalLines: [
                  if (activeDays.isNotEmpty)
                    HorizontalLine(
                      y: avgMood,
                      color: NeuroColors.electricPink.withValues(alpha: 0.55),
                      strokeWidth: 1,
                      dashArray: [6, 5],
                    ),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideCard(BuildContext context, Map<String, dynamic> guide) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final panelColor = dark
        ? NeuroColors.darkCard.withValues(alpha: 0.72)
        : Colors.white.withValues(alpha: 0.90);
    final titleColor = dark ? Colors.white : NeuroColors.ink;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _showArticle(context, guide),
      child: Container(
        decoration: BoxDecoration(
          color: panelColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.24),
          ),
          boxShadow: [
            BoxShadow(
              color: dark
                  ? theme.colorScheme.primary.withValues(alpha: 0.10)
                  : Colors.black.withValues(alpha: 0.07),
              blurRadius: dark ? 18 : 14,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.asset(
                    guide["image"],
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: theme.colorScheme.primary.withValues(alpha: 0.14),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.44),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 10,
                  bottom: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.46),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: NeuroColors.teal.withValues(alpha: 0.42),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(guide["icon"], color: NeuroColors.teal, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          guide["minutes"],
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    guide["title"],
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: titleColor,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    guide["author"],
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: NeuroColors.teal,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    guide["description"],
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactGuideTile(
      BuildContext context, Map<String, dynamic> guide) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final panelColor = dark
        ? NeuroColors.darkCard.withValues(alpha: 0.74)
        : Colors.white.withValues(alpha: 0.92);
    final titleColor = dark ? Colors.white : NeuroColors.ink;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _showArticle(context, guide),
      child: Container(
        height: 124,
        decoration: BoxDecoration(
          color: panelColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.24),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            SizedBox(
              width: 116,
              height: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    guide["image"],
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: theme.colorScheme.primary.withValues(alpha: 0.14),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.50),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child:
                        Icon(guide["icon"], color: NeuroColors.teal, size: 20),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            guide["title"],
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: titleColor,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          guide["minutes"],
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: NeuroColors.teal,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      guide["description"],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.25),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategory(
    BuildContext context,
    String categoryName,
    List<Map<String, dynamic>> guides,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isMobile = width < NeuroBreakpoints.mobile;
        final columns = width >= 980
            ? 3
            : width >= 650
                ? 2
                : 1;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 26),
            Row(
              children: [
                Expanded(
                  child: Text(
                    categoryName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                Icon(Icons.chevron_right,
                    color: Theme.of(context).colorScheme.primary),
              ],
            ),
            const SizedBox(height: 12),
            if (isMobile)
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: guides.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) =>
                    _buildCompactGuideTile(context, guides[index]),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: guides.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: columns == 1 ? 1.02 : 0.92,
                ),
                itemBuilder: (context, index) =>
                    _buildGuideCard(context, guides[index]),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Guides"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: NeuroShell(
        padding: EdgeInsets.zero,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: neuroPagePadding(width),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const NeuroSectionLabel(
                        text: "Guided Support", icon: Icons.menu_book),
                    const SizedBox(height: 8),
                    Text(
                      "Small practices for steadier days",
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Choose a quick exercise, reflect for a few minutes, and return to your journal with more clarity.",
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                    ),
                    const SizedBox(height: 18),
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else
                      _buildDailyMoodChart(context),
                    ...guidesByCategory.entries.map(
                      (entry) =>
                          _buildCategory(context, entry.key, entry.value),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GuideDetailPage extends StatelessWidget {
  const _GuideDetailPage({required this.guide});

  final Map<String, dynamic> guide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final titleColor = theme.colorScheme.onSurface;
    return Scaffold(
      appBar: AppBar(
        title: Text(guide["title"]),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: NeuroShell(
        padding: EdgeInsets.zero,
        child: SingleChildScrollView(
          padding: neuroPagePadding(width),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: NeuroGlowFrame(
                child: NeuroCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(8),
                        ),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Image.asset(
                            guide["image"],
                            fit: BoxFit.cover,
                            width: double.infinity,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            NeuroSectionLabel(
                              text: guide["minutes"],
                              icon: guide["icon"],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              guide["title"],
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: titleColor,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              guide["author"],
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: NeuroColors.teal,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              guide["description"],
                              style: theme.textTheme.bodyLarge?.copyWith(
                                height: 1.55,
                              ),
                            ),
                            const SizedBox(height: 22),
                            FilledButton.icon(
                              style: neuroFilledButton(context),
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.check_circle_outline),
                              label: const Text("Done"),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
