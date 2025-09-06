import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class GuidesPage extends StatelessWidget {
  const GuidesPage({super.key});

  // Sample daily moods (1–5 scale)
  final List<Map<String, dynamic>> dailyMoods = const [
    {"day": "Mon", "mood": 4},
    {"day": "Tue", "mood": 3},
    {"day": "Wed", "mood": 5},
    {"day": "Thu", "mood": 2},
    {"day": "Fri", "mood": 4},
    {"day": "Sat", "mood": 5},
    {"day": "Sun", "mood": 3},
  ];

  final Map<String, List<Map<String, dynamic>>> guidesByCategory = const {
    "Mind & Gratitude": [
      {
        "title": "Catch a Pleasant Event Daily",
        "author": "Blakie Sahay",
        "description":
            "Reflect on daily positive moments to boost happiness. Notice small joys around you.",
        "image": "assets/images/mind1.png",
        "gradient": [Colors.red, Colors.orange],
      },
      {
        "title": "Mindful Breathing",
        "author": "Zen Master",
        "description":
            "Short breathing exercises calm the mind. Inhale deeply, exhale slowly for 5–10 minutes.",
        "image": "assets/images/mind2.png",
        "gradient": [Colors.blue, Colors.purple],
      },
      {
        "title": "Gratitude Journal",
        "author": "Daily Practice",
        "description":
            "Write down three things you are grateful for each day to improve mental wellbeing.",
        "image": "assets/images/mind3.png",
        "gradient": [Colors.green, Colors.teal],
      },
    ],
    "Personal Growth": [
      {
        "title": "Navigating Thresholds of Big Change",
        "author": "Reboot Coaching",
        "description":
            "Transitions are hard to navigate. Acknowledge emotions, set achievable goals, and seek support.",
        "image": "assets/images/growth1.png",
        "gradient": [Colors.green, Colors.yellow],
      },
      {
        "title": "Turn Lemons Into Lemonade",
        "author": "Someone",
        "description":
            "Transform challenges into opportunities. Learn from setbacks to build resilience.",
        "image": "assets/images/growth2.png",
        "gradient": [Colors.pink, Colors.orange],
      },
      {
        "title": "Setting SMART Goals",
        "author": "Goal Guru",
        "description":
            "Learn to set Specific, Measurable, Achievable, Relevant, and Time-bound goals.",
        "image": "assets/images/growth3.png",
        "gradient": [Colors.blue, Colors.indigo],
      },
    ],
    "Health & Wellness": [
      {
        "title": "Morning Stretch Routine",
        "author": "Fit Life",
        "description":
            "Start your day with simple stretches to increase flexibility and boost energy.",
        "image": "assets/images/health1.png",
        "gradient": [Colors.teal, Colors.cyan],
      },
      {
        "title": "Healthy Eating Habits",
        "author": "Nutritionist",
        "description":
            "Incorporate balanced meals with vegetables, proteins, and whole grains.",
        "image": "assets/images/health2.png",
        "gradient": [Colors.orange, Colors.red],
      },
      {
        "title": "Mindful Sleep",
        "author": "Sleep Expert",
        "description":
            "Establish a sleep routine, limit screen time, and create a calm environment.",
        "image": "assets/images/health3.png",
        "gradient": [Colors.deepPurple, Colors.blue],
      },
    ],
  };

  void _showArticle(BuildContext context, Map<String, dynamic> guide) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(guide["title"])),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (guide["image"] != null && guide["image"].isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.asset(
                        guide["image"],
                        fit: BoxFit.cover,
                        width: double.infinity,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  guide["title"],
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  "Author: ${guide["author"]}",
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                Text(
                  guide["description"],
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(
      BuildContext context, Map<String, dynamic> guide, double cardWidth) {
    return GestureDetector(
      onTap: () => _showArticle(context, guide),
      child: Container(
        width: cardWidth,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: guide["gradient"],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (guide["image"] != null && guide["image"].isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.asset(
                    guide["image"],
                    fit: BoxFit.cover,
                    width: double.infinity,
                  ),
                ),
              ),
            const SizedBox(height: 6),
            Text(
              guide["title"],
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              guide["author"],
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Color _moodColor(int mood) {
    if (mood >= 4) return Colors.green;
    if (mood == 3) return Colors.orange;
    return Colors.red;
  }

  Widget _buildDailyMoodChart() {
    final todayIndex = DateTime.now().weekday - 1; // Mon=1 → index=0
    final avgMood =
        dailyMoods.map((e) => e["mood"] as int).reduce((a, b) => a + b) /
            dailyMoods.length;

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: 5,
          gridData: FlGridData(show: true, drawVerticalLine: true),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 28),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  int index = value.toInt();
                  if (index >= 0 && index < dailyMoods.length) {
                    return Text(dailyMoods[index]["day"]);
                  }
                  return const Text('');
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: true),
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(
                dailyMoods.length,
                (index) =>
                    FlSpot(index.toDouble(), dailyMoods[index]["mood"].toDouble()),
              ),
              isCurved: true,
              color: Colors.purpleAccent,
              barWidth: 3,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  final moodValue = dailyMoods[index.toInt()]["mood"] as int;
                  final color = index == todayIndex
                      ? Colors.blueAccent
                      : _moodColor(moodValue);
                  final radius = index == todayIndex ? 6.5 : 4.5;
                  return FlDotCirclePainter(color: color, radius: radius);
                },
              ),
            ),
          ],
          extraLinesData: ExtraLinesData(horizontalLines: [
            HorizontalLine(
                y: avgMood,
                color: Colors.grey.shade400,
                strokeWidth: 1,
                dashArray: [5, 5],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topLeft,
                  labelResolver: (line) => 'Avg',
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ))
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;

    return Scaffold(
      appBar: AppBar(title: const Text("Guides")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              "Daily Mood Chart",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildDailyMoodChart(),
            const SizedBox(height: 24),
            ...guidesByCategory.entries.map((category) {
              final String categoryName = category.key;
              final List<Map<String, dynamic>> guides = category.value;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 16),
                  Text(
                    categoryName,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 220,
                    child: isMobile
                        ? ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: guides.length,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 12),
                            itemBuilder: (context, index) {
                              final guide = guides[index];
                              return _buildCard(context, guide, 160);
                            },
                          )
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: guides
                                  .map((guide) => Padding(
                                        padding:
                                            const EdgeInsets.only(right: 12),
                                        child: _buildCard(context, guide, 200),
                                      ))
                                  .toList(),
                            ),
                          ),
                  ),
                ],
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}
