import 'package:flutter/material.dart';
import 'db_helper.dart';
import 'login_page.dart';
import 'add_journal_page.dart';
import 'guides_page.dart';
import 'screens/advanced_dashboard.dart';
import 'services/gamification_service.dart';
import 'services/notification_service.dart';
import 'theme/nuromood_ui.dart';

class JournalHomePage extends StatefulWidget {
  final int userId;
  final void Function(bool)? toggleTheme;
  final bool isDarkMode;

  const JournalHomePage({
    super.key,
    required this.userId,
    this.toggleTheme,
    required this.isDarkMode,
  });

  @override
  State<JournalHomePage> createState() => _JournalHomePageState();
}

class _JournalHomePageState extends State<JournalHomePage> {
  final DBHelper dbHelper = DBHelper();
  List<Map<String, dynamic>> journalEntries = [];
  Map<String, dynamic>? selectedEntry;
  bool isLoading = true;
  bool showInsights = false;

  @override
  void initState() {
    super.initState();
    _loadJournals();
  }

  Future<void> _loadJournals() async {
    setState(() => isLoading = true);
    journalEntries = await dbHelper.getJournals(widget.userId);
    await NotificationService.instance.scheduleDailyJournalReminder(
      hour: GamificationService.preferredReminderHour(journalEntries),
    );
    if (!mounted) return;
    setState(() => isLoading = false);
  }

  Color _getMoodColor(String mood) {
    switch (mood.toLowerCase()) {
      case 'joy':
        return const Color(0xFF7CCBA2);
      case 'sadness':
        return const Color(0xFF5B8DEF);
      case 'anger':
        return const Color(0xFFEF6F6C);
      case 'fear':
      case 'anxiety':
        return const Color(0xFF8B5CF6);
      default:
        return const Color(0xFF9CA3AF);
    }
  }

  Future<void> _addJournal(String text, String mood, {String? image}) async {
    await dbHelper.insertJournal(widget.userId, text, mood, image: image);
    await _loadJournals();
  }

  void _showAddEntryPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddJournalPage(
          userId: widget.userId,
          onAdd: (text, mood, {String? image}) async {
            await _addJournal(text, mood, image: image);
          },
        ),
      ),
    );
  }

  void _showEditEntryPage(Map<String, dynamic> entry) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddJournalPage(
          userId: widget.userId,
          initialText: entry['text'],
          initialMood: entry['mood'],
          initialImage: entry['image_path'],
          onAdd: (text, mood, {String? image}) async {
            await dbHelper.updateJournal(widget.userId, entry['id'], text, mood,
                image: image);
            await _loadJournals();
          },
        ),
      ),
    );
  }

  Widget _sidebar() {
    final theme = Theme.of(context);

    Widget item(IconData icon, String title, VoidCallback onTap) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        child: ListTile(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          leading: Icon(icon, color: theme.colorScheme.primary),
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          onTap: onTap,
        ),
      );
    }

    return Container(
      width: 240,
      margin: const EdgeInsets.all(14),
      child: NeuroCard(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const MoodBrand(compact: true),
                  const SizedBox(height: 16),
                  Chip(
                    avatar: const Icon(Icons.local_fire_department, size: 18),
                    label: Text("${_currentStreak()} Day Streak"),
                  ),
                ],
              ),
            ),
            item(Icons.insights, "Insights",
                () => setState(() => showInsights = true)),
            item(Icons.today, "Today", _showTodayEntries),
            item(Icons.book, "Journals", () async {
              setState(() => showInsights = false);
              await _loadJournals();
            }),
            item(Icons.add, "New Entry", _showAddEntryPage),
            item(Icons.menu_book, "Guides", () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GuidesPage(userId: widget.userId),
                ),
              );
            }),
            item(Icons.delete, "Trash", _showTrash),
          ],
        ),
      ),
    );
  }

  void _showTodayEntries() async {
    final today = DateTime.now();
    final todayStr =
        "${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
    final todayEntries =
        await dbHelper.getJournalsByDate(widget.userId, todayStr);
    if (!mounted) return;
    if (todayEntries.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("No entries for today")));
      return;
    }
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Today's Entries"),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: todayEntries.length,
            itemBuilder: (context, index) {
              final entry = todayEntries[index];
              return ListTile(
                  title: Text(entry['text']),
                  subtitle: Text("Mood: ${entry['mood']}"));
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"))
        ],
      ),
    );
  }

  void _showTrash() async {
    final trash = await dbHelper.getTrash(widget.userId);
    if (!mounted) return;
    if (trash.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Trash is empty")));
      return;
    }
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Trash"),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: trash.length,
            itemBuilder: (context, index) {
              final entry = trash[index];
              final deletedAt =
                  DateTime.tryParse(entry['deleted_at']?.toString() ?? '');
              final daysLeft = deletedAt == null
                  ? 30
                  : 30 - DateTime.now().difference(deletedAt).inDays;
              return ListTile(
                title: Text(entry['text']),
                subtitle: Text(
                    "Mood: ${entry['mood']} - ${daysLeft.clamp(0, 30)} days left"),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.restore, color: Colors.green),
                      onPressed: () async {
                        await dbHelper.restoreFromTrash(
                            widget.userId, entry['id']);
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        await _loadJournals();
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_forever, color: Colors.red),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text("Delete Forever"),
                            content: const Text(
                                "Are you sure you want to permanently delete this journal entry?"),
                            actions: [
                              TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text("Cancel")),
                              TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text("Delete")),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await dbHelper.deleteForever(
                              widget.userId, entry['id']);
                          if (!context.mounted) return;
                          Navigator.pop(context);
                          await _loadJournals();
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"))
        ],
      ),
    );
  }

  Widget _journalList() {
    if (isLoading) return const Center(child: CircularProgressIndicator());

    final now = DateTime.now();
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final compact = width < NeuroBreakpoints.mobile;

    final monthNames = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec"
    ];
    final monthYearText = "${monthNames[now.month - 1]} ${now.year}";

    if (journalEntries.isEmpty) {
      return SingleChildScrollView(
        padding: neuroPagePadding(width),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: NeuroCard(
              padding: EdgeInsets.all(compact ? 18 : 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_note,
                      size: 52, color: theme.colorScheme.primary),
                  const SizedBox(height: 12),
                  Text("No journal entries yet",
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(
                    "Write your first reflection when you are ready.",
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                      onPressed: _showAddEntryPage,
                      icon: const Icon(Icons.add),
                      label: const Text("New Entry")),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
              compact ? 14 : 22, compact ? 14 : 20, compact ? 14 : 22, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const NeuroSectionLabel(
                        text: "Journal", icon: Icons.auto_awesome),
                    const SizedBox(height: 4),
                    Text(monthYearText,
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
              Chip(
                avatar: const Icon(Icons.auto_graph, size: 16),
                label: Text("${journalEntries.length} entries"),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: theme.dividerColor),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.fromLTRB(
                compact ? 10 : 18, 10, compact ? 10 : 18, compact ? 96 : 28),
            itemCount: journalEntries.length,
            itemBuilder: (context, index) =>
                _journalEntryCard(journalEntries[index], compact: compact),
          ),
        ),
      ],
    );
  }

  Widget _journalEntryCard(Map<String, dynamic> entry,
      {required bool compact}) {
    final theme = Theme.of(context);
    final date = DateTime.tryParse(entry['date'] ?? "") ?? DateTime.now();
    final dayName =
        ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][date.weekday - 1];
    final dayNumber = date.day;
    final mood = entry['mood']?.toString() ?? "neutral";

    return Card(
      color: theme.cardColor.withValues(alpha: 0.94),
      margin: EdgeInsets.symmetric(horizontal: compact ? 0 : 4, vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
            color: theme.colorScheme.primary.withValues(alpha: 0.24)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => setState(() => selectedEntry = entry),
        child: Padding(
          padding:
              EdgeInsets.fromLTRB(compact ? 10 : 14, 12, compact ? 6 : 10, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 54,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_getMoodColor(mood), NeuroColors.lavender],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: _getMoodColor(mood).withValues(alpha: 0.30),
                      blurRadius: 16,
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("$dayNumber",
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 17)),
                    Text(dayName,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 10)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry['text']?.toString() ?? "",
                      maxLines: compact ? 3 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _miniChip(
                            Icons.mood, "Mood: $mood", _getMoodColor(mood)),
                        if ((entry['image_path']?.toString() ?? "").isNotEmpty)
                          _miniChip(Icons.image, "Image",
                              theme.colorScheme.secondary),
                      ],
                    ),
                  ],
                ),
              ),
              compact
                  ? PopupMenuButton<String>(
                      tooltip: "Entry actions",
                      onSelected: (value) {
                        if (value == "edit") _showEditEntryPage(entry);
                        if (value == "delete") _confirmMoveToTrash(entry);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: "edit", child: Text("Edit")),
                        PopupMenuItem(
                            value: "delete", child: Text("Move to Trash")),
                      ],
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                            tooltip: "Edit",
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _showEditEntryPage(entry)),
                        IconButton(
                            tooltip: "Move to Trash",
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _confirmMoveToTrash(entry)),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Future<void> _confirmMoveToTrash(Map<String, dynamic> entry) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Move to Trash"),
        content: const Text("Move this entry to Trash?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Move")),
        ],
      ),
    );
    if (confirm == true) {
      await dbHelper.moveToTrash(widget.userId, entry['id']);
      if (selectedEntry == entry) selectedEntry = null;
      await _loadJournals();
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= NeuroBreakpoints.desktop;
    final theme = Theme.of(context);
    final isDarkModeNow = theme.brightness == Brightness.dark;

    final appBar = AppBar(
      title: const MoodBrand(compact: true),
      backgroundColor: Colors.transparent,
      elevation: 0,
      actions: [
        IconButton(
          tooltip: isDarkModeNow ? "Use light mode" : "Use dark mode",
          icon: Icon(isDarkModeNow ? Icons.dark_mode : Icons.light_mode),
          onPressed: () => widget.toggleTheme?.call(!isDarkModeNow),
        ),
        IconButton(
          tooltip: "Logout",
          icon: const Icon(Icons.logout),
          onPressed: () async {
            await dbHelper.logout();
            if (!context.mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => LoginPage(
                  toggleTheme: widget.toggleTheme,
                  isDarkMode: Theme.of(context).brightness == Brightness.dark,
                ),
              ),
            );
          },
        ),
      ],
    );

    if (isDesktop) {
      return Scaffold(body: _webDashboard(theme));
    } else {
      return Scaffold(
        appBar: appBar,
        drawer: Drawer(child: _sidebar()),
        body: NeuroShell(
          padding: EdgeInsets.zero,
          child: showInsights
              ? AdvancedDashboard(
                  userId: widget.userId,
                  streak: _currentStreak(),
                  entries: journalEntries,
                )
              : _journalList(),
        ),
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: theme.colorScheme.primary.withValues(alpha: 0.18),
              ),
            ),
          ),
          child: NavigationBar(
            selectedIndex: showInsights ? 1 : 0,
            onDestinationSelected: (index) {
              if (index == 0) setState(() => showInsights = false);
              if (index == 1) setState(() => showInsights = true);
              if (index == 2) _showAddEntryPage();
              if (index == 3) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GuidesPage(userId: widget.userId),
                  ),
                );
              }
            },
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.bookmark_border_rounded),
                  selectedIcon: Icon(Icons.bookmark_rounded),
                  label: "Journal"),
              NavigationDestination(
                  icon: Icon(Icons.auto_graph_rounded),
                  selectedIcon: Icon(Icons.auto_graph_rounded),
                  label: "Insights"),
              NavigationDestination(
                  icon: Icon(Icons.edit_outlined),
                  selectedIcon: Icon(Icons.edit),
                  label: "Write"),
              NavigationDestination(
                  icon: Icon(Icons.menu_book_outlined),
                  selectedIcon: Icon(Icons.menu_book),
                  label: "Guides"),
            ],
          ),
        ),
        floatingActionButton: width < NeuroBreakpoints.mobile
            ? null
            : FloatingActionButton.extended(
                onPressed: _showAddEntryPage,
                icon: const Icon(Icons.edit),
                label: const Text("Journal"),
              ),
      );
    }
  }

  Widget _webDashboard(ThemeData theme) {
    final dark = theme.brightness == Brightness.dark;
    return NeuroShell(
      padding: neuroPagePadding(MediaQuery.of(context).size.width),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            children: [
              _webTopBar(theme),
              const SizedBox(height: 16),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: 220, child: _webSideNav(theme)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: dark
                                ? NeuroColors.dark.withValues(alpha: 0.28)
                                : Colors.white.withValues(alpha: 0.42),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: theme.colorScheme.primary
                                  .withValues(alpha: dark ? 0.22 : 0.12),
                            ),
                          ),
                          child: showInsights
                              ? AdvancedDashboard(
                                  userId: widget.userId,
                                  streak: _currentStreak(),
                                  entries: journalEntries,
                                )
                              : _journalList(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(width: 260, child: _webActionRail(theme)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _webTopBar(ThemeData theme) {
    return Row(
      children: [
        const MoodBrand(),
        const Spacer(),
        _webIconButton(
          theme,
          tooltip: "Today",
          icon: Icons.calendar_month_outlined,
          onTap: _showTodayEntries,
        ),
        const SizedBox(width: 8),
        _webIconButton(
          theme,
          tooltip: Theme.of(context).brightness == Brightness.dark
              ? "Use light mode"
              : "Use dark mode",
          icon: Theme.of(context).brightness == Brightness.dark
              ? Icons.dark_mode
              : Icons.light_mode,
          onTap: () => widget.toggleTheme
              ?.call(Theme.of(context).brightness != Brightness.dark),
        ),
        const SizedBox(width: 8),
        _webIconButton(
          theme,
          tooltip: "Logout",
          icon: Icons.logout,
          onTap: () async {
            await dbHelper.logout();
            if (!mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => LoginPage(
                  toggleTheme: widget.toggleTheme,
                  isDarkMode: Theme.of(context).brightness == Brightness.dark,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _webSideNav(ThemeData theme) {
    return NeuroCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _webNavItem(
            theme,
            icon: Icons.bookmark_border_rounded,
            selectedIcon: Icons.bookmark_rounded,
            label: "Journal",
            selected: !showInsights,
            onTap: () => setState(() => showInsights = false),
          ),
          _webNavItem(
            theme,
            icon: Icons.auto_graph_rounded,
            selectedIcon: Icons.auto_graph_rounded,
            label: "Insights",
            selected: showInsights,
            onTap: () => setState(() => showInsights = true),
          ),
          _webNavItem(
            theme,
            icon: Icons.edit_outlined,
            selectedIcon: Icons.edit,
            label: "Write",
            selected: false,
            onTap: _showAddEntryPage,
          ),
          _webNavItem(
            theme,
            icon: Icons.menu_book_outlined,
            selectedIcon: Icons.menu_book,
            label: "Guides",
            selected: false,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GuidesPage(userId: widget.userId),
                ),
              );
            },
          ),
          const Spacer(),
          _webStatTile(
            theme,
            icon: Icons.local_fire_department_rounded,
            value: "${_currentStreak()}",
            label: "Day streak",
          ),
          const SizedBox(height: 10),
          _webStatTile(
            theme,
            icon: Icons.book_rounded,
            value: "${journalEntries.length}",
            label: "Entries",
          ),
        ],
      ),
    );
  }

  Widget _webNavItem(
    ThemeData theme, {
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final dark = theme.brightness == Brightness.dark;
    final color = selected
        ? (dark ? NeuroColors.teal : theme.colorScheme.primary)
        : theme.colorScheme.onSurface.withValues(alpha: 0.70);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? theme.colorScheme.primary.withValues(alpha: dark ? 0.16 : 0.10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            child: Row(
              children: [
                Icon(selected ? selectedIcon : icon, color: color, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _webIconButton(
    ThemeData theme, {
    required String tooltip,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: theme.colorScheme.surface.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.18)),
            ),
            child: Icon(icon, color: theme.colorScheme.primary),
          ),
        ),
      ),
    );
  }

  Widget _webActionRail(ThemeData theme) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _quickJournalCard(theme),
          const SizedBox(height: 12),
          _recentInsightsCard(theme),
          const SizedBox(height: 12),
          _webSupportCard(theme),
        ],
      ),
    );
  }

  Widget _webStatTile(
    ThemeData theme, {
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900)),
              Text(label, style: theme.textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }

  Widget _webSupportCard(ThemeData theme) {
    return NeuroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const NeuroSectionLabel(
              text: "Support", icon: Icons.health_and_safety_outlined),
          const SizedBox(height: 8),
          Text("Safety and premium tools",
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Text(
            "Fast access to upgrade details, privacy notes, and crisis support.",
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: neuroFilledButton(context),
              onPressed: () => _showSafetyDialog(theme),
              icon: const Icon(Icons.phone_in_talk_outlined),
              label: const Text("Safety"),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showPremiumDialog(theme),
              icon: const Icon(Icons.star_outline_rounded),
              label: const Text("Premium"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickJournalCard(ThemeData theme) {
    return NeuroCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: _showAddEntryPage,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text("Quick Journal Entry",
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const Chip(
                      avatar: Icon(Icons.lock, size: 15),
                      label: Text("Privacy Locked")),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                height: 104,
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(alpha: 0.62),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Text("Start a private reflection...",
                    style: theme.textTheme.bodyMedium),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: Icon(Icons.lock,
                    color: theme.colorScheme.primary, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _recentInsightsCard(ThemeData theme) {
    final latest = journalEntries.isNotEmpty ? journalEntries.first : null;
    return NeuroCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(backgroundImage: null, child: Icon(Icons.person)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Recent AI Insights",
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text("Just now", style: theme.textTheme.bodySmall),
                const SizedBox(height: 10),
                Text(
                  latest == null
                      ? "Write an entry to generate emotion, trigger, and coping insights."
                      : "Detected emotion: ${latest['mood']}. Trigger patterns and coping recommendations are ready.",
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text("Mood: ${latest?['mood'] ?? 'Neutral'}")),
                    const Chip(label: Text("Privacy-first")),
                    const Chip(label: Text("Trigger words")),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _currentStreak() {
    return GamificationService.currentStreak(journalEntries);
  }

  void _showPremiumDialog(ThemeData theme) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.star_rounded, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            const Text('Premium Features'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Unlock the full Nuromood experience:',
                style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            _premiumFeatureRow(Icons.insights, 'Advanced AI mood insights'),
            _premiumFeatureRow(Icons.mic, 'Voice journaling & tone analysis'),
            _premiumFeatureRow(
                Icons.picture_as_pdf, 'Clinical-grade data export'),
            _premiumFeatureRow(
                Icons.notifications_active, 'Smart reminders & nudges'),
            _premiumFeatureRow(Icons.lock_open, 'Unlimited journal history'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe Later'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.star_rounded),
            label: const Text('Upgrade Now'),
          ),
        ],
      ),
    );
  }

  Widget _premiumFeatureRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: NeuroColors.teal),
          const SizedBox(width: 10),
          Text(text, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  void _showSafetyDialog(ThemeData theme) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.health_and_safety, color: theme.colorScheme.error),
            const SizedBox(width: 8),
            const Text('Safety & Ethical AI'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your wellbeing is our priority. Nuromood is designed with ethical AI principles:',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            _safetyRow(Icons.lock, 'All data is stored locally — never sold.'),
            _safetyRow(Icons.psychology, 'AI provides support, not diagnosis.'),
            _safetyRow(Icons.verified_user, 'GDPR & privacy-first by design.'),
            _safetyRow(Icons.phone_in_talk, 'Crisis helplines available 24/7.'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: NeuroColors.blush,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'If you are in crisis, please reach out to a mental health professional or call your local emergency number.',
                style: TextStyle(fontSize: 12, color: NeuroColors.ink),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.phone_in_talk),
            label: const Text('Get Help'),
          ),
        ],
      ),
    );
  }

  Widget _safetyRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: NeuroColors.lavender),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
