import 'dart:convert';
import 'dart:typed_data';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../services/entitlement_service.dart';
import '../services/gamification_service.dart';
import '../theme/nuromood_ui.dart';

class AdvancedDashboard extends StatefulWidget {
  const AdvancedDashboard({
    super.key,
    required this.userId,
    required this.streak,
    required this.entries,
  });

  final int userId;
  final int streak;
  final List<Map<String, dynamic>> entries;

  @override
  State<AdvancedDashboard> createState() => _AdvancedDashboardState();
}

class _AdvancedDashboardState extends State<AdvancedDashboard> {
  int _trendDays = 7;
  UserEntitlement _entitlement = UserEntitlement.free;

  @override
  void initState() {
    super.initState();
    _loadEntitlement();
  }

  Future<void> _loadEntitlement() async {
    final entitlement = await EntitlementService().getEntitlement(widget.userId);
    if (!mounted) return;
    setState(() {
      _entitlement = entitlement;
      if (!_entitlement.isPremium && _trendDays > _entitlement.chartsDays) {
        _trendDays = _entitlement.chartsDays;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeEntries = widget.entries.where((e) => e['is_deleted'] != 1).toList();
    final badges = GamificationService.badges(activeEntries);

    return NeuroShell(
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Insights', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              Chip(
                avatar: const Icon(Icons.local_fire_department, size: 18),
                label: Text('${widget.streak} Day Streak'),
              ),
              PopupMenuButton<String>(
                tooltip: 'Export',
                icon: const Icon(Icons.ios_share),
                onSelected: (value) async {
                  if (!_entitlement.clinicalExport) {
                    _showUpgrade(context, "Clinical exports are available on Premium");
                    return;
                  }
                  if (value == 'pdf') {
                    await _exportPdf(activeEntries);
                  } else {
                    await _exportJson(activeEntries);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'pdf', child: Text('Export PDF')),
                  PopupMenuItem(value: 'json', child: Text('Export JSON')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _AnalyticsCard(title: 'Milestones', child: _BadgeGrid(badges: badges)),
          const SizedBox(height: 16),
          _AnalyticsCard(title: 'Mood Calendar', child: _MoodCalendar(entries: activeEntries)),
          const SizedBox(height: 16),
          _AnalyticsCard(
            title: 'Mood Trend',
            child: Column(
              children: [
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 7, label: Text('7D')),
                    ButtonSegment(value: 30, label: Text('30D')),
                  ],
                  selected: {_trendDays},
                  onSelectionChanged: (value) {
                    final requested = value.first;
                    if (requested > _entitlement.chartsDays) {
                      _showUpgrade(context, "30-day charts are available on Premium");
                      return;
                    }
                    setState(() => _trendDays = requested);
                  },
                ),
                if (!_entitlement.isPremium)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      "Free tier includes 7-day charts. Premium unlocks 30-day trends, voice journaling, and exports.",
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                const SizedBox(height: 12),
                _MoodLineChart(entries: activeEntries, days: _trendDays),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _AnalyticsCard(title: 'Trigger Correlation', child: _TriggerBarChart(entries: activeEntries)),
        ],
      ),
      ),
    );
  }

  Future<void> _exportPdf(List<Map<String, dynamic>> entries) async {
    final bytes = await _buildClinicalPdf(entries);
    await Printing.sharePdf(bytes: bytes, filename: 'nuromood_clinical_report.pdf');
  }

  Future<void> _exportJson(List<Map<String, dynamic>> entries) async {
    final payload = {
      'generated_at': DateTime.now().toIso8601String(),
      'privacy_note': 'This export is generated locally from the app cache.',
      'summary': _summary(entries),
      'entries': entries,
    };
    final bytes = Uint8List.fromList(utf8.encode(const JsonEncoder.withIndent('  ').convert(payload)));
    await Share.shareXFiles([
      XFile.fromData(
        bytes,
        mimeType: 'application/json',
        name: 'nuromood_clinical_report.json',
      )
    ]);
  }

  void _showUpgrade(BuildContext context, String message) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Unlock Premium"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 14),
            const _PremiumMiniPlan(),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Not now")),
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text("Upgrade")),
        ],
      ),
    );
  }
}

class _AnalyticsCard extends StatelessWidget {
  const _AnalyticsCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return NeuroCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _PremiumMiniPlan extends StatelessWidget {
  const _PremiumMiniPlan();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NeuroColors.aqua.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Premium includes"),
          SizedBox(height: 6),
          Text("- 30-day trends"),
          Text("- Voice journaling"),
          Text("- Clinical PDF/JSON export"),
        ],
      ),
    );
  }
}

class _BadgeGrid extends StatelessWidget {
  const _BadgeGrid({required this.badges});

  final List<MoodBadge> badges;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 640 ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: badges.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: columns == 3 ? 2.6 : 2.1,
          ),
          itemBuilder: (context, index) {
            final badge = badges[index];
            return AnimatedOpacity(
              opacity: badge.unlocked ? 1 : 0.45,
              duration: const Duration(milliseconds: 200),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: badge.unlocked
                      ? theme.colorScheme.primary.withValues(alpha: 0.10)
                      : theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: badge.unlocked ? theme.colorScheme.primary : theme.dividerColor,
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: badge.unlocked
                          ? theme.colorScheme.primary
                          : theme.disabledColor.withValues(alpha: 0.20),
                      child: Icon(
                        badge.unlocked ? Icons.workspace_premium : Icons.lock_outline,
                        color: badge.unlocked ? theme.colorScheme.onPrimary : theme.disabledColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            badge.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            badge.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _MoodCalendar extends StatelessWidget {
  const _MoodCalendar({required this.entries});

  final List<Map<String, dynamic>> entries;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final monthStart = DateTime(today.year, today.month, 1);
    final leading = monthStart.weekday % 7;
    final firstCell = monthStart.subtract(Duration(days: leading));
    final days = List.generate(42, (index) => firstCell.add(Duration(days: index)));

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            _Weekday('S'),
            _Weekday('M'),
            _Weekday('T'),
            _Weekday('W'),
            _Weekday('T'),
            _Weekday('F'),
            _Weekday('S'),
          ],
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: days.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemBuilder: (context, index) {
            final day = days[index];
            final mood = _dominantMoodForDay(entries, day);
            final muted = day.month != today.month;
            return DecoratedBox(
              decoration: BoxDecoration(
                color: _moodColor(mood).withValues(alpha: mood == null ? 0.06 : 0.18),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: DateUtils.isSameDay(day, today)
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    '${day.day}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: muted ? Theme.of(context).disabledColor : null,
                        ),
                  ),
                  if (mood != null)
                    Positioned(
                      bottom: 6,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(color: _moodColor(mood), shape: BoxShape.circle),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _Weekday extends StatelessWidget {
  const _Weekday(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(child: Text(label, style: Theme.of(context).textTheme.labelSmall)),
    );
  }
}

class _MoodLineChart extends StatelessWidget {
  const _MoodLineChart({required this.entries, required this.days});

  final List<Map<String, dynamic>> entries;
  final int days;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final dates = List.generate(
      days,
      (index) => DateTime(today.year, today.month, today.day).subtract(Duration(days: days - 1 - index)),
    );
    final spots = <FlSpot>[
      for (var i = 0; i < dates.length; i++)
        FlSpot(i.toDouble(), _averageMoodScoreForDay(entries, dates[i])),
    ];

    return SizedBox(
      height: 210,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: 5,
          gridData: FlGridData(show: true, horizontalInterval: 1),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 34,
                interval: 1,
                getTitlesWidget: (value, meta) => Text(value.toInt().toString()),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: days == 7 ? 1 : 5,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= dates.length) {
                    return const SizedBox.shrink();
                  }
                  return Text('${dates[index].day}', style: const TextStyle(fontSize: 10));
                },
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Theme.of(context).colorScheme.primary,
              barWidth: 3,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
              ),
            ),
          ],
          lineTouchData: const LineTouchData(enabled: true),
        ),
      ),
    );
  }
}

class _TriggerBarChart extends StatelessWidget {
  const _TriggerBarChart({required this.entries});

  final List<Map<String, dynamic>> entries;

  @override
  Widget build(BuildContext context) {
    final correlations = _triggerCorrelations(entries);
    if (correlations.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('No trigger patterns yet'),
      );
    }

    return Column(
      children: correlations.entries.map((entry) {
        final trigger = entry.key;
        final value = entry.value;
        final total = value.positive + value.negative;
        final negativeShare = total == 0 ? 0.0 : value.negative / total;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(width: 88, child: Text(trigger)),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: negativeShare,
                        minHeight: 12,
                        backgroundColor: const Color(0xFF7CCBA2).withValues(alpha: 0.35),
                        valueColor: const AlwaysStoppedAnimation(Color(0xFFEF6F6C)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('${(negativeShare * 100).round()}% stress'),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${value.negative} negative / ${value.positive} positive entries',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

Future<Uint8List> _buildClinicalPdf(List<Map<String, dynamic>> entries) async {
  final doc = pw.Document();
  final summary = _summary(entries);
  final rows = entries.take(90).map((entry) {
    return [
      _formatDate(entry['date']),
      '${entry['mood'] ?? 'neutral'}',
      '${((entry['confidence'] as num?)?.toDouble() ?? 0) * 100}'.split('.').first,
      _triggerText(entry),
    ];
  }).toList();

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) => [
        pw.Text('NeuroMood Clinical Mood Report', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Text('Generated: ${DateTime.now().toIso8601String()}'),
        pw.Text('Privacy note: this report is generated locally from app cache.'),
        pw.SizedBox(height: 18),
        pw.Text('Summary', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.Bullet(text: 'Entries: ${summary['entry_count']}'),
        pw.Bullet(text: 'Dominant mood: ${summary['dominant_mood']}'),
        pw.Bullet(text: 'Negative entries: ${summary['negative_entries']}'),
        pw.Bullet(text: 'Positive entries: ${summary['positive_entries']}'),
        pw.SizedBox(height: 18),
        pw.Text('Recent Entries', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.TableHelper.fromTextArray(
          headers: const ['Date', 'Mood', 'Confidence %', 'Triggers'],
          data: rows,
          cellStyle: const pw.TextStyle(fontSize: 9),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
      ],
    ),
  );
  return doc.save();
}

Map<String, dynamic> _summary(List<Map<String, dynamic>> entries) {
  final moodCounts = <String, int>{};
  var positive = 0;
  var negative = 0;
  for (final entry in entries) {
    final mood = entry['mood']?.toString().toLowerCase() ?? 'neutral';
    moodCounts[mood] = (moodCounts[mood] ?? 0) + 1;
    if (_isNegativeMood(mood)) negative++;
    if (_isPositiveMood(mood)) positive++;
  }
  final dominant = moodCounts.entries.isEmpty
      ? 'neutral'
      : moodCounts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  return {
    'entry_count': entries.length,
    'dominant_mood': dominant,
    'negative_entries': negative,
    'positive_entries': positive,
  };
}

String? _dominantMoodForDay(List<Map<String, dynamic>> entries, DateTime day) {
  final counts = <String, int>{};
  for (final entry in entries) {
    final parsed = DateTime.tryParse(entry['date']?.toString() ?? '');
    if (parsed != null && parsed.year == day.year && parsed.month == day.month && parsed.day == day.day) {
      final mood = entry['mood']?.toString();
      if (mood != null) counts[mood] = (counts[mood] ?? 0) + 1;
    }
  }
  if (counts.isEmpty) return null;
  return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
}

double _averageMoodScoreForDay(List<Map<String, dynamic>> entries, DateTime day) {
  final scores = <int>[];
  for (final entry in entries) {
    final parsed = DateTime.tryParse(entry['date']?.toString() ?? '');
    if (parsed != null && parsed.year == day.year && parsed.month == day.month && parsed.day == day.day) {
      scores.add(_moodScore(entry['mood']?.toString()));
    }
  }
  if (scores.isEmpty) return 3;
  return scores.reduce((a, b) => a + b) / scores.length;
}

Map<String, _TriggerStats> _triggerCorrelations(List<Map<String, dynamic>> entries) {
  final stats = <String, _TriggerStats>{
    'Office': _TriggerStats(),
    'Relationship': _TriggerStats(),
    'Exam': _TriggerStats(),
    'Money': _TriggerStats(),
    'Health': _TriggerStats(),
  };
  for (final entry in entries) {
    final text = '${entry['text'] ?? ''}'.toLowerCase();
    final mood = entry['mood']?.toString().toLowerCase() ?? 'neutral';
    final matched = <String>{
      if (text.contains('work') || text.contains('office') || text.contains('boss')) 'Office',
      if (text.contains('family') || text.contains('friend') || text.contains('partner')) 'Relationship',
      if (text.contains('exam') || text.contains('assignment')) 'Exam',
      if (text.contains('money') || text.contains('bill') || text.contains('loan')) 'Money',
      if (text.contains('sick') || text.contains('pain') || text.contains('stress')) 'Health',
    };
    for (final trigger in matched) {
      if (_isNegativeMood(mood)) {
        stats[trigger]!.negative++;
      } else if (_isPositiveMood(mood)) {
        stats[trigger]!.positive++;
      }
    }
  }
  stats.removeWhere((key, value) => value.positive + value.negative == 0);
  final sorted = stats.entries.toList()
    ..sort((a, b) => (b.value.positive + b.value.negative).compareTo(a.value.positive + a.value.negative));
  return Map.fromEntries(sorted);
}

String _formatDate(dynamic raw) {
  final parsed = DateTime.tryParse(raw?.toString() ?? '');
  if (parsed == null) return '';
  return '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
}

String _triggerText(Map<String, dynamic> entry) {
  final text = '${entry['text'] ?? ''}'.toLowerCase();
  final triggers = <String>[
    if (text.contains('work') || text.contains('office') || text.contains('boss')) 'Office',
    if (text.contains('family') || text.contains('friend') || text.contains('partner')) 'Relationship',
    if (text.contains('exam') || text.contains('assignment')) 'Exam',
    if (text.contains('money') || text.contains('bill') || text.contains('loan')) 'Money',
    if (text.contains('sick') || text.contains('pain') || text.contains('stress')) 'Health',
  ];
  return triggers.join(', ');
}

bool _isPositiveMood(String mood) => mood == 'joy' || mood == 'love' || mood == 'surprise';
bool _isNegativeMood(String mood) => mood == 'sadness' || mood == 'anger' || mood == 'fear' || mood == 'anxiety';

int _moodScore(String? mood) {
  switch (mood?.toLowerCase()) {
    case 'joy':
    case 'love':
      return 5;
    case 'surprise':
      return 4;
    case 'fear':
    case 'anxiety':
      return 2;
    case 'sadness':
    case 'anger':
      return 1;
    default:
      return 3;
  }
}

Color _moodColor(String? mood) {
  switch (mood?.toLowerCase()) {
    case 'joy':
      return const Color(0xFF4CAF50);
    case 'love':
      return const Color(0xFFE889B5);
    case 'sadness':
      return const Color(0xFF5B8DEF);
    case 'fear':
    case 'anxiety':
      return const Color(0xFF8B5CF6);
    case 'anger':
      return const Color(0xFFEF6F6C);
    case 'surprise':
      return const Color(0xFFF7B955);
    default:
      return const Color(0xFF9CA3AF);
  }
}

class _TriggerStats {
  int positive = 0;
  int negative = 0;
}
