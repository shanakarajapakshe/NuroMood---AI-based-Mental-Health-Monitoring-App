import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;

import '../models/journal_analysis.dart';
import '../app_config.dart';

class JournalApiService {
  JournalApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final String apiBase = 'http://127.0.0.1:5000';

  Future<JournalAnalysis?> analyzeAndSaveJournal({
    required int userId,
    required String text,
    String? imagePath,
  }) async {
    if (AppConfig.isDemo) return null;
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      await queueOfflineJournal({
        'user_id': userId,
        'text': text,
        'image_path': imagePath,
      });
      return null;
    }

    final response = await _client.post(
      Uri.parse('$apiBase/analyze_text'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'text': _anonymizeForModel(text)}),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final json = Map<String, dynamic>.from(jsonDecode(response.body));
      return JournalAnalysis.fromJson({
        'journal_id': '',
        'primary_emotion': json['primary_emotion'] ?? json['prediction'],
        'confidence': json['confidence'] ?? 0,
        'confidence_percent': json['confidence_percent'] ?? 0,
        'scores': json['scores'] ?? const {},
        'top_emotions': json['top_emotions'] ?? const [],
        'triggers': json['triggers'] ?? const [],
        'sentiment_shift': json['sentiment_shift'] ?? const {},
        'coping_plan': json['coping_plan'] ?? const {},
        'streak': const {'current': 0},
        'crisis_flag': json['crisis_flag'] == true,
        'crisis_signal': json['crisis_signal'],
      });
    }
    debugPrint(
        'Analyze journal failed: ${response.statusCode} ${response.body}');
    return null;
  }

  Future<void> queueOfflineJournal(Map<String, dynamic> payload) async {
    final box = await Hive.openBox('offline_journal_queue');
    await box.add({
      'payload': payload,
      'queued_at': DateTime.now().toUtc().toIso8601String(),
      'sync_status': 'pending',
    });
  }

  Future<void> syncQueuedJournals() async {
    final box = await Hive.openBox('offline_journal_queue');
    for (final key in box.keys.toList()) {
      final item = Map<String, dynamic>.from(box.get(key));
      if (item['sync_status'] != 'pending') continue;
      final response = await _client.post(
        Uri.parse('$apiBase/analyze-journal'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(item['payload']),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        await box.delete(key);
      }
    }
  }

  String _anonymizeForModel(String text) {
    return text
        .replaceAll(
            RegExp(r'[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}',
                caseSensitive: false),
            '[email]')
        .replaceAll(RegExp(r'\+?\d[\d\s-]{7,}\d'), '[phone]');
  }
}
