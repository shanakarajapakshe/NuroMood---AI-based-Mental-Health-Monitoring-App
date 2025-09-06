import 'package:flutter/material.dart';
import 'db_helper.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class AddJournalPage extends StatefulWidget {
  final int userId;
  final Future<void> Function(String text, String mood, {String? image}) onAdd;
  final String? initialText;
  final String? initialMood;
  final String? initialImage;

  const AddJournalPage({
    super.key,
    required this.userId,
    required this.onAdd,
    this.initialText,
    this.initialMood,
    this.initialImage,
  });

  @override
  State<AddJournalPage> createState() => _AddJournalPageState();
}

class _AddJournalPageState extends State<AddJournalPage> {
  late TextEditingController _journalController;
  File? _selectedImage;
  bool isLoading = false;
  final String apiBase = "http://192.168.1.144:5000";

  @override
  void initState() {
    super.initState();
    _journalController = TextEditingController(text: widget.initialText ?? "");
    if (widget.initialImage != null && widget.initialImage!.isNotEmpty) {
      _selectedImage = File(widget.initialImage!);
    }
  }

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> saveJournal() async {
    final text = _journalController.text.trim();
    if (text.isEmpty) return;

    setState(() => isLoading = true);
    String mood = await getMoodFromText(text);

    await widget.onAdd(
      text,
      mood,
      image: (_selectedImage != null && _selectedImage!.path.isNotEmpty)
          ? _selectedImage!.path
          : null,
    );

    setState(() => isLoading = false);
    Navigator.pop(context);
  }

  Future<String> getMoodFromText(String text) async {
    try {
      final response = await http
          .post(
            Uri.parse('$apiBase/analyze_text'),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"text": text}),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['prediction'] ?? "joy";
      } else {
        debugPrint("Mood API returned status ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Mood API error: $e");
    }
    return "joy"; // fallback
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // dynamic theming

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.initialText == null ? "New Journal Entry" : "Edit Journal"),
        centerTitle: true,
        elevation: 0,
        backgroundColor: theme.appBarTheme.backgroundColor,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: theme.shadowColor.withOpacity(0.2),
                  blurRadius: 12,
                  spreadRadius: 2,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  "Write Your Thoughts",
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _journalController,
                  maxLines: 6,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: theme.inputDecorationTheme.fillColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    hintText: "How was your day?",
                  ),
                ),
                const SizedBox(height: 20),
                if (_selectedImage != null && _selectedImage!.path.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(
                      _selectedImage!,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.primary,
                  ),
                  onPressed: pickImage,
                  icon: const Icon(Icons.image),
                  label: const Text("Add Image"),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: isLoading ? null : saveJournal,
                    child: isLoading
                        ? CircularProgressIndicator(
                            color: theme.colorScheme.onPrimary)
                        : Text(
                            widget.initialText == null
                                ? "Add Entry"
                                : "Save Changes",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
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
}
