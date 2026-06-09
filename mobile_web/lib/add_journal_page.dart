import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'services/journal_api_service.dart';
import 'services/entitlement_service.dart';
import 'widgets/coping_exercise_sheet.dart';
import 'widgets/crisis_support_overlay.dart';
import 'theme/nuromood_ui.dart';
import 'app_config.dart';

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
  XFile? _selectedImage;
  bool isLoading = false;
  bool isRecording = false;
  UserEntitlement _entitlement = UserEntitlement.free;
  String _voiceBaseText = "";
  late stt.SpeechToText _speech;
  final JournalApiService _journalApi = JournalApiService();
  final String apiBase = "http://127.0.0.1:5000";

  @override
  void initState() {
    super.initState();
    _journalController = TextEditingController(text: widget.initialText ?? "");
    _speech = stt.SpeechToText();
    _loadEntitlement();
    if (widget.initialImage != null && widget.initialImage!.isNotEmpty) {
      _selectedImage = XFile(widget.initialImage!);
    }
  }

  Future<void> _loadEntitlement() async {
    final entitlement =
        await EntitlementService().getEntitlement(widget.userId);
    if (!mounted) return;
    setState(() => _entitlement = entitlement);
  }

  @override
  void dispose() {
    _speech.stop();
    _journalController.dispose();
    super.dispose();
  }

  Future<void> toggleVoiceJournaling() async {
    if (!_entitlement.voiceJournaling) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Voice journaling is available on Premium")),
      );
      return;
    }
    if (isRecording) {
      await _speech.stop();
      if (!mounted) return;
      setState(() => isRecording = false);
      return;
    }

    final available = await _speech.initialize();
    if (!mounted) return;
    if (!available) return;

    _voiceBaseText = _journalController.text.trimRight();
    setState(() => isRecording = true);
    await _speech.listen(
      onResult: (result) {
        setState(() {
          final separator = _voiceBaseText.isEmpty ? "" : "\n";
          _journalController.text =
              "$_voiceBaseText$separator${result.recognizedWords}";
          _journalController.selection = TextSelection.fromPosition(
            TextPosition(offset: _journalController.text.length),
          );
        });
      },
    );
  }

  void _wrapSelection(String prefix, String suffix) {
    final value = _journalController.value;
    final selection = value.selection;
    final text = value.text;
    if (!selection.isValid) return;
    final selected = selection.textInside(text);
    final replacement = '$prefix$selected$suffix';
    final updated =
        text.replaceRange(selection.start, selection.end, replacement);
    final cursor = selection.start + replacement.length;
    _journalController.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: cursor),
    );
  }

  void _insertLinePrefix(String prefix) {
    final value = _journalController.value;
    final cursor = value.selection.baseOffset < 0
        ? value.text.length
        : value.selection.baseOffset;
    final lineStart =
        cursor <= 0 ? 0 : value.text.lastIndexOf('\n', cursor - 1) + 1;
    final updated = value.text.replaceRange(lineStart, lineStart, prefix);
    _journalController.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: cursor + prefix.length),
    );
  }

  Widget _formatToolbar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            tooltip: 'Bold',
            icon: const Icon(Icons.format_bold),
            onPressed: () => _wrapSelection('**', '**'),
          ),
          IconButton(
            tooltip: 'Bullets',
            icon: const Icon(Icons.format_list_bulleted),
            onPressed: () => _insertLinePrefix('- '),
          ),
          IconButton(
            tooltip: 'Heading',
            icon: const Icon(Icons.title),
            onPressed: () => _insertLinePrefix('## '),
          ),
          IconButton(
            tooltip: 'Quote',
            icon: const Icon(Icons.format_quote),
            onPressed: () => _insertLinePrefix('> '),
          ),
        ],
      ),
    );
  }

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = pickedFile;
      });
    }
  }

  Widget _selectedImagePreview() {
    final image = _selectedImage;
    if (image == null || image.path.isEmpty) return const SizedBox.shrink();

    return FutureBuilder<Uint8List>(
      future: image.readAsBytes(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            height: 180,
            width: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color:
                  Theme.of(context).colorScheme.surface.withValues(alpha: 0.55),
            ),
            child: const CircularProgressIndicator(strokeWidth: 2),
          );
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.memory(
            snapshot.data!,
            height: 200,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        );
      },
    );
  }

  Future<void> saveJournal() async {
    final text = _journalController.text.trim();
    if (text.isEmpty) return;

    setState(() => isLoading = true);
    final analysis = await _journalApi.analyzeAndSaveJournal(
      userId: widget.userId,
      text: text,
      imagePath: (_selectedImage != null && _selectedImage!.path.isNotEmpty)
          ? _selectedImage!.path
          : null,
    );
    String mood = analysis?.primaryEmotion ?? await getMoodFromText(text);

    await widget.onAdd(
      text,
      mood,
      image: (_selectedImage != null && _selectedImage!.path.isNotEmpty)
          ? _selectedImage!.path
          : null,
    );

    if (!mounted) return;
    setState(() => isLoading = false);
    if (analysis?.crisisFlag == true) {
      await CrisisSupportOverlay.show(
        context,
        onDismissed: () {
          debugPrint('Crisis overlay dismissed by user');
        },
        onAction: (action) => _logCrisisAction(action, analysis),
      );
    } else if (analysis?.copingPlan != null) {
      await CopingExerciseSheet.show(context, analysis!.copingPlan!);
    }
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<String> getMoodFromText(String text) async {
    if (AppConfig.isDemo) {
      final value = text.toLowerCase();
      if (value.contains(RegExp(r'\b(happy|proud|excited|great|joy)\b'))) {
        return 'joy';
      }
      if (value.contains(RegExp(r'\b(sad|hurt|lonely|disappointed)\b'))) {
        return 'sadness';
      }
      if (value.contains(RegExp(r'\b(angry|mad|frustrated)\b'))) {
        return 'anger';
      }
      if (value.contains(RegExp(r'\b(anxious|worried|stress|afraid)\b'))) {
        return 'anxiety';
      }
      if (value.contains(RegExp(r'\b(love|grateful|connected)\b'))) {
        return 'love';
      }
      return 'neutral';
    }
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

  Future<void> _logCrisisAction(String action, dynamic analysis) async {
    try {
      await http.post(
        Uri.parse('$apiBase/crisis-events'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": widget.userId,
          "journal_id": analysis?.journalId,
          "signal": analysis?.crisisSignal ?? "ui_interaction",
          "confidence": analysis?.confidence ?? 0,
          "user_action": action,
        }),
      );
    } catch (e) {
      debugPrint("Crisis action log error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // dynamic theming
    final width = MediaQuery.of(context).size.width;
    final compact = width < NeuroBreakpoints.mobile;

    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.initialText == null ? "New Journal Entry" : "Edit Journal"),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: NeuroShell(
        child: Center(
          child: SingleChildScrollView(
            padding: neuroPagePadding(width),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: NeuroCard(
                padding: EdgeInsets.all(compact ? 16 : 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        Text(
                          "Write Your Thoughts",
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Chip(
                          avatar: Icon(Icons.lock,
                              size: 16, color: theme.colorScheme.primary),
                          label: const Text("Encrypted locally"),
                          side: BorderSide(
                              color: theme.colorScheme.primary
                                  .withValues(alpha: 0.25)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _formatToolbar(theme),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _journalController,
                      minLines: compact ? 9 : 11,
                      maxLines: compact ? 14 : 18,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor:
                            theme.colorScheme.surface.withValues(alpha: 0.72),
                        hintText: "Start writing here...",
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_selectedImage != null &&
                        _selectedImage!.path.isNotEmpty)
                      _selectedImagePreview(),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        OutlinedButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: theme.colorScheme.primary,
                          ),
                          onPressed: pickImage,
                          icon: const Icon(Icons.image),
                          label: const Text("Add Image"),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.colorScheme.primary
                                .withValues(alpha: isRecording ? 0.18 : 0.06),
                            boxShadow: isRecording
                                ? [
                                    BoxShadow(
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.25),
                                      blurRadius: 18,
                                      spreadRadius: 3,
                                    )
                                  ]
                                : const [],
                          ),
                          child: IconButton(
                            tooltip: isRecording
                                ? 'Stop voice journaling'
                                : 'Voice journaling',
                            onPressed: toggleVoiceJournaling,
                            icon: Icon(
                              _entitlement.voiceJournaling
                                  ? (isRecording ? Icons.mic : Icons.mic_none)
                                  : Icons.lock_outline,
                            ),
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: neuroFilledButton(context),
                        onPressed: isLoading ? null : saveJournal,
                        child: isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
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
        ),
      ),
    );
  }
}
