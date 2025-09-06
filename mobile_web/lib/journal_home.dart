import 'package:flutter/material.dart';
import 'db_helper.dart';
import 'login_page.dart';
import 'add_journal_page.dart';
import 'dart:io';
import 'guides_page.dart';


class JournalHomePage extends StatefulWidget {
  final int userId;
  final void Function(bool)? toggleTheme;
  final bool isDarkMode;

  const JournalHomePage({
    Key? key,
    required this.userId,
    this.toggleTheme,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  State<JournalHomePage> createState() => _JournalHomePageState();
}


class _JournalHomePageState extends State<JournalHomePage> {
  final DBHelper dbHelper = DBHelper();
  List<Map<String, dynamic>> journalEntries = [];
  Map<String, dynamic>? selectedEntry;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadJournals();
  }

  Future<void> _loadJournals() async {
    setState(() => isLoading = true);
    journalEntries = await dbHelper.getJournals(widget.userId);
    setState(() => isLoading = false);
  }

  Color _getMoodColor(String mood) {
    switch (mood.toLowerCase()) {
      case 'joy':
        return Colors.yellow[700]!;
      case 'sadness':
        return Colors.blue[400]!;
      case 'anger':
        return Colors.red[400]!;
      case 'fear':
        return Colors.purple[400]!;
      default:
        return Colors.grey;
    }
  }

  Future<void> _addJournal(String text, String mood, {String? image}) async {
    await dbHelper.insertJournal(widget.userId, text, mood, image: image);
    await _loadJournals();
    _showMoodTip();
  }

  void _showMoodTip() {
    if (journalEntries.isEmpty) return;
    final recentEntries = journalEntries.take(3);
    int badDays = recentEntries.where((e) =>
        ["sadness", "anger", "fear"].contains((e['mood'] ?? "joy").toLowerCase())).length;

    String tip = "";
    if (badDays == 3) tip = "💡 Rough few days! Take a break or meditate.";
    else if (badDays == 2) tip = "💡 Try relaxation or a short walk.";
    else if (badDays == 1) tip = "💡 It's okay to feel down. Do something enjoyable.";

    if (tip.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("Mood Tip"),
            content: Text(tip),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))
            ],
          ),
        );
      });
    }
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
            await dbHelper.updateJournal(widget.userId, entry['id'], text, mood, image: image);
            await _loadJournals();
          },
        ),
      ),
    );
  }

  Widget _sidebar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
final Color startColor = isDark ? const Color(0xFF1C1C20) : const Color(0xFF8A82FF);
final Color endColor = isDark ? const Color(0xFF121212) : const Color(0xFFB8B0FF);
final Color textColor = isDark ? Colors.white : Colors.black;


    Widget item(IconData icon, String title, VoidCallback onTap) {
      return ListTile(
        leading: Icon(icon, color: textColor),
        title: Text(title, style: TextStyle(color: textColor)),
        onTap: onTap,
      );
    }

    return Container(
      width: 220,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [startColor, endColor], begin: Alignment.topCenter, end: Alignment.bottomCenter),
      ),
      child: ListView(
        children: [
          Container(
            height: 100,
            padding: const EdgeInsets.all(16),
            alignment: Alignment.centerLeft,
            child: Text("📓 Journal (${journalEntries.length})", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
          ),
          item(Icons.today, "Today", _showTodayEntries),
          item(Icons.book, "Journals", _loadJournals),
          item(Icons.add, "New Entry", _showAddEntryPage),
          item(Icons.menu_book, "Guides", () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const GuidesPage()),
        );
      }),
          item(Icons.delete, "Trash", _showTrash),

        ],
      ),
    );
  }

  void _showTodayEntries() async {
    final today = DateTime.now();
    final todayStr = "${today.year.toString().padLeft(4,'0')}-${today.month.toString().padLeft(2,'0')}-${today.day.toString().padLeft(2,'0')}";
    final todayEntries = await dbHelper.getJournalsByDate(widget.userId, todayStr);
    if (todayEntries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No entries for today")));
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
              return ListTile(title: Text(entry['text']), subtitle: Text("Mood: ${entry['mood']}"));
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))],
      ),
    );
  }

  void _showTrash() async {
    final trash = await dbHelper.getTrash(widget.userId);
    if (trash.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Trash is empty")));
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
              return ListTile(
                title: Text(entry['text']),
                subtitle: Text("Mood: ${entry['mood']}"),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.restore, color: Colors.green),
                      onPressed: () async {
                        await dbHelper.restoreFromTrash(widget.userId, entry['id']);
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
                            content: const Text("Are you sure you want to permanently delete this journal entry?"),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
                              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete")),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await dbHelper.deleteForever(widget.userId, entry['id']);
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
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))],
      ),
    );
  }

Widget _journalList() {
  if (isLoading) return const Center(child: CircularProgressIndicator());
  if (journalEntries.isEmpty) return const Center(child: Text("No journal entries yet"));

  final now = DateTime.now();
  final theme = Theme.of(context);

  // Month name for header
  final monthNames = [
    "Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"
  ];
  final monthYearText = "${monthNames[now.month - 1]} ${now.year}";

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.all(12.0),
        child: Text(monthYearText, style: theme.textTheme.titleLarge),
      ),
      Divider(color: theme.dividerColor),
      Expanded(
        child: ListView.builder(
          itemCount: journalEntries.length,
          itemBuilder: (context, index) {
            final entry = journalEntries[index];
            final date = DateTime.tryParse(entry['date'] ?? "") ?? DateTime.now();
            final dayName = ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"][date.weekday - 1];
            final dayNumber = date.day;

            return Card(
              color: theme.cardColor,
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _getMoodColor(entry['mood']),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("$dayNumber", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      Text(dayName, style: const TextStyle(color: Colors.white, fontSize: 10)),
                    ],
                  ),
                ),
                title: Text(
                  entry['text'],
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge,
                ),
                subtitle: Text("Mood: ${entry['mood']}", style: theme.textTheme.bodyMedium),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.edit, color: Colors.blueAccent), onPressed: () => _showEditEntryPage(entry)),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text("Move to Trash"),
                            content: const Text("Move this entry to Trash?"),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
                              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Move")),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await dbHelper.moveToTrash(widget.userId, entry['id']);
                          if (selectedEntry == entry) selectedEntry = null;
                          await _loadJournals();
                        }
                      },
                    ),
                  ],
                ),
                onTap: () => setState(() => selectedEntry = entry),
              ),
            );
          },
        ),
      ),
    ],
  );
}


  Widget _detailView() {
    if (selectedEntry == null) return const Center(child: Text("Select a journal entry"));
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      color: theme.scaffoldBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(selectedEntry!['text'], style: theme.textTheme.titleLarge),
          const SizedBox(height: 10),
          Text("Mood: ${selectedEntry!['mood']}", style: theme.textTheme.bodyLarge),
          if (selectedEntry!['image_path'] != null && selectedEntry!['image_path'].isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Image.file(File(selectedEntry!['image_path']), height: 200, fit: BoxFit.cover),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 800;
    final theme = Theme.of(context);

    final appBar = AppBar(
  title: const Text("Nuromood Journal"),
  actions: [
    Row(
      children: [
        const Icon(Icons.light_mode),
        Switch(
  value: widget.isDarkMode,
  onChanged: (val) => widget.toggleTheme?.call(val),
  activeColor: theme.colorScheme.secondary,
),

        const Icon(Icons.dark_mode),
      ],
    ),
    IconButton(
      icon: const Icon(Icons.logout),
      onPressed: () async {
        await dbHelper.logout();
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
      },
    ),
  ],
    );

    if (isDesktop) {
      return Scaffold(
        appBar: appBar,
        body: Row(
          children: [
            _sidebar(),
            Expanded(flex: 2, child: _journalList()),
            Expanded(flex: 3, child: _detailView()),
          ],
        ),
      );
    } else {
      return Scaffold(
        appBar: appBar,
        drawer: Drawer(child: _sidebar()),
        body: _journalList(),
        floatingActionButton: FloatingActionButton(onPressed: _showAddEntryPage, child: const Icon(Icons.add)),
      );
    }
  }
}
