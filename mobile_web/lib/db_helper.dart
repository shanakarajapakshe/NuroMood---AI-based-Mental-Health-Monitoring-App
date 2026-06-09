import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:path/path.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'services/security_service.dart';
import 'app_config.dart';

class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  factory DBHelper() => _instance;
  DBHelper._internal();

  late Database _db;
  final String apiBase = "http://127.0.0.1:5000";

  int? _currentUserId;

  Box? _journalBox;
  Box? _sessionBox;
  Box? _syncQueueBox;

  /// Initialize DB (SQLite for mobile/desktop, Hive for web)
  Future<void> init() async {
    await Hive.initFlutter();
    _journalBox = await Hive.openBox('journals');
    _sessionBox = await Hive.openBox('session');
    _syncQueueBox = await Hive.openBox('journal_sync_queue');
    if (AppConfig.isDemo) {
      await _seedDemoJournals();
    }

    if (!kIsWeb) {
      if (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      }

      final path = join(await getDatabasesPath(), 'nuromood.db');
      _db = await openDatabase(
        path,
        version: 1,
        onCreate: (db, version) async {
          // Users table
          await db.execute('''
            CREATE TABLE users(
              id INTEGER PRIMARY KEY,
              email TEXT UNIQUE,
              password TEXT
            )
          ''');
          // Journals table
          await db.execute('''
            CREATE TABLE journals(
              id INTEGER PRIMARY KEY,
              user_id INTEGER,
              text TEXT,
              mood TEXT,
              date TEXT,
              image_path TEXT,
              is_deleted INTEGER DEFAULT 0,
              deleted_at TEXT,
              sync_status TEXT DEFAULT 'synced'
            )
          ''');
        },
        onOpen: (db) async {
          await _ensureLocalColumn(db, 'journals', 'deleted_at', 'TEXT');
          await _ensureLocalColumn(
              db, 'journals', 'sync_status', "TEXT DEFAULT 'synced'");
        },
      );
    }

    await purgeExpiredTrash();
    if (!AppConfig.isDemo) {
      await syncPendingJournals();
    }
    // Load current user session
    await _loadCurrentUser();
  }

  Future<void> _ensureLocalColumn(
      Database db, String table, String column, String definition) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    final exists = columns.any((row) => row['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }

  // ------------------- Session -------------------

  Future<void> _loadCurrentUser() async {
    if (AppConfig.isDemo) {
      _currentUserId = AppConfig.demoUserId;
      return;
    }

    // Check Hive first
    final hiveUser = _sessionBox?.get('user_id');
    if (hiveUser != null) {
      _currentUserId =
          hiveUser is int ? hiveUser : int.tryParse(hiveUser.toString());
      return;
    }

    // If Hive empty, fallback to SQLite last user
    if (!kIsWeb) {
      final result = await _db.query(
        'users',
        columns: ['id'],
        limit: 1,
        orderBy: 'id DESC',
      );
      if (result.isNotEmpty) {
        final rawUserId = result.first['id'];
        if (rawUserId != null) {
          _currentUserId =
              rawUserId is int ? rawUserId : int.tryParse(rawUserId.toString());
        }
      }
    }
  }

  Future<int?> getCurrentUser() async => _currentUserId;

  Future<void> logout() async {
    _currentUserId = null;
    await _sessionBox?.clear();

    if (!kIsWeb) {
      await _db.delete('journals'); // optional: keep users for login
    }
  }

  // ------------------- User Auth -------------------

  Future<bool> registerUser(String email, String password) async {
    if (AppConfig.isDemo) return true;
    try {
      final response = await http.post(
        Uri.parse('$apiBase/register'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "password": password}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Register error: $e");
      return false;
    }
  }

  Future<int?> loginUser(String email, String password) async {
    if (AppConfig.isDemo) {
      _currentUserId = AppConfig.demoUserId;
      await _sessionBox?.put('user_id', AppConfig.demoUserId);
      return AppConfig.demoUserId;
    }

    try {
      final response = await http.post(
        Uri.parse('$apiBase/login'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "password": password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final userId = data['user_id'] as int;
        _currentUserId = userId;

        // Save session in Hive
        await _sessionBox?.put('user_id', userId);

        // Ensure user exists in SQLite
        if (!kIsWeb) {
          await _db.insert(
            'users',
            {'id': userId, 'email': email, 'password': password},
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        // Fetch journals after login
        await syncPendingJournals();
        await getJournals(userId, refresh: true);

        return userId;
      }
    } catch (e) {
      debugPrint("Login error: $e");
    }
    return null;
  }

  // ------------------- Journals -------------------

  Future<List<Map<String, dynamic>>> getJournals(int userId,
      {bool refresh = false}) async {
    List<Map<String, dynamic>> journals = [];
    if (!AppConfig.isDemo) {
      await syncPendingJournals();
    }

    if (!refresh) {
      if (kIsWeb && _journalBox != null && _journalBox!.isNotEmpty) {
        journals = _journalBox!.values
            .where((e) =>
                e is Map && e['user_id'] == userId && e['is_deleted'] == 0)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        if (journals.isNotEmpty || AppConfig.isDemo) {
          journals.sort(
              (a, b) => b['date'].toString().compareTo(a['date'].toString()));
          return journals;
        }
      } else if (!kIsWeb) {
        journals = await _db.query(
          'journals',
          where: 'user_id = ? AND is_deleted = 0',
          whereArgs: [userId],
          orderBy: 'date DESC',
        );
        if (journals.isNotEmpty) return journals;
      }
    }

    if (AppConfig.isDemo) return journals;

    // Fetch from API
    try {
      final response = await http.get(Uri.parse('$apiBase/journals/$userId'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        journals = data.map((e) => Map<String, dynamic>.from(e)).toList();

        if (kIsWeb) {
          await _journalBox?.clear();
          for (var entry in journals) {
            await _journalBox?.put(entry['id'].toString(), entry);
          }
        } else {
          for (var entry in journals) {
            await _db.insert('journals', entry,
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
      }
    } catch (e) {
      debugPrint("Fetch journals API error: $e");
    }

    return journals;
  }

  Future<void> insertJournal(int userId, String text, String mood,
      {String? image}) async {
    final id = DateTime.now().millisecondsSinceEpoch;
    final entry = {
      'id': id,
      'user_id': userId,
      'text': text,
      'mood': mood,
      'image_path': image ?? '',
      'date': DateTime.now().toIso8601String(),
      'is_deleted': 0,
      'deleted_at': null,
      'sync_status': 'pending',
    };

    if (kIsWeb) {
      await _journalBox?.put(id.toString(), entry);
    } else {
      await _db.insert('journals', entry);
    }

    if (AppConfig.isDemo) {
      entry['sync_status'] = 'local-demo';
      await _saveLocalEntry(id.toString(), entry);
      return;
    }

    try {
      final encrypted = await SecurityService.instance.encryptJournalText(text);
      await http.post(
        Uri.parse('$apiBase/journals/$userId'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "encrypted_journal": encrypted.toJson(),
          "mood": mood,
          "image_path": image,
        }),
      );
      entry['sync_status'] = 'synced';
      await _saveLocalEntry(id.toString(), entry);
    } catch (e) {
      debugPrint("Insert journal API error: $e");
      await _queueSync({
        'op': 'insert',
        'user_id': userId,
        'entry_id': id,
        'text': text,
        'mood': mood,
        'image_path': image,
      });
    }
  }

  Future<void> moveToTrash(int userId, int entryId) async {
    await _updateJournalStatus(userId, entryId, 1,
        deletedAt: DateTime.now().toIso8601String());
    if (AppConfig.isDemo) return;
    try {
      await http.delete(Uri.parse('$apiBase/journals/$userId/$entryId'));
    } catch (e) {
      debugPrint("Move to trash API error: $e");
      await _queueSync({'op': 'trash', 'user_id': userId, 'entry_id': entryId});
    }
  }

  Future<void> restoreFromTrash(int userId, int entryId) async {
    await _updateJournalStatus(userId, entryId, 0, deletedAt: null);
    if (AppConfig.isDemo) return;
    try {
      await http.post(Uri.parse('$apiBase/journals/$userId/$entryId/restore'));
    } catch (e) {
      debugPrint("Restore API error: $e");
      await _queueSync(
          {'op': 'restore', 'user_id': userId, 'entry_id': entryId});
    }
  }

  Future<List<Map<String, dynamic>>> getJournalsByDate(int userId, String date,
      {bool refresh = false}) async {
    List<Map<String, dynamic>> journals = [];

    // Check local cache first
    if (!refresh) {
      if (kIsWeb && _journalBox != null) {
        journals = _journalBox!.values
            .where((e) =>
                e is Map &&
                e['user_id'] == userId &&
                e['is_deleted'] == 0 &&
                (e['date'] as String).startsWith(date))
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        if (journals.isNotEmpty) return journals;
      } else if (!kIsWeb) {
        journals = await _db.query(
          'journals',
          where: 'user_id = ? AND is_deleted = 0 AND date LIKE ?',
          whereArgs: [userId, '$date%'],
          orderBy: 'date DESC',
        );
        if (journals.isNotEmpty) return journals;
      }
    }

    if (AppConfig.isDemo) return journals;

    // Fetch from API
    try {
      final response =
          await http.get(Uri.parse('$apiBase/journals/$userId/date/$date'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        journals = data.map((e) => Map<String, dynamic>.from(e)).toList();

        // Save locally
        if (kIsWeb) {
          for (var entry in journals) {
            await _journalBox?.put(entry['id'].toString(), entry);
          }
        } else {
          for (var entry in journals) {
            await _db.insert('journals', entry,
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
      }
    } catch (e) {
      debugPrint("Fetch journals by date API error: $e");
    }

    return journals;
  }

  Future<void> _updateJournalStatus(int userId, int entryId, int isDeleted,
      {String? deletedAt}) async {
    if (kIsWeb) {
      final entry = _journalBox?.get(entryId.toString());
      if (entry != null) {
        final updated = Map<String, dynamic>.from(entry);
        updated['is_deleted'] = isDeleted;
        updated['deleted_at'] = deletedAt;
        updated['sync_status'] = 'pending';
        await _journalBox?.put(entryId.toString(), updated);
      }
    } else {
      await _db.update(
        'journals',
        {
          'is_deleted': isDeleted,
          'deleted_at': deletedAt,
          'sync_status': 'pending'
        },
        where: 'user_id = ? AND id = ?',
        whereArgs: [userId, entryId],
      );
    }
  }

// ------------------- Update Journal -------------------
  Future<void> updateJournal(int userId, int entryId, String text, String mood,
      {String? image}) async {
    final updatedEntry = {
      'text': text,
      'mood': mood,
      'image_path': image ?? '',
      'date': DateTime.now().toIso8601String(),
      'sync_status': 'pending',
    };

    // Update locally
    if (kIsWeb) {
      final entry = _journalBox?.get(entryId.toString());
      if (entry != null) {
        final updated = Map<String, dynamic>.from(entry)..addAll(updatedEntry);
        await _journalBox?.put(entryId.toString(), updated);
      }
    } else {
      await _db.update(
        'journals',
        updatedEntry,
        where: 'user_id = ? AND id = ?',
        whereArgs: [userId, entryId],
      );
    }

    // Send update to API
    if (AppConfig.isDemo) {
      final entry = _journalBox?.get(entryId.toString());
      if (entry != null) {
        final local = Map<String, dynamic>.from(entry);
        local['sync_status'] = 'local-demo';
        await _journalBox?.put(entryId.toString(), local);
      }
      return;
    }

    try {
      final encrypted = await SecurityService.instance.encryptJournalText(text);
      await http.put(
        Uri.parse('$apiBase/journals/$userId/$entryId'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          'encrypted_journal': encrypted.toJson(),
          'mood': mood,
          'image_path': image
        }),
      );
    } catch (e) {
      debugPrint("Update journal API error: $e");
      await _queueSync({
        'op': 'update',
        'user_id': userId,
        'entry_id': entryId,
        'text': text,
        'mood': mood,
        'image_path': image,
      });
    }
  }

  Future<void> deleteForever(int userId, int journalId) async {
    if (!kIsWeb) {
      await _db.delete(
        'journals',
        where: 'id = ? AND user_id = ? AND is_deleted = 1',
        whereArgs: [journalId, userId],
      );
    } else if (_journalBox != null) {
      // For web (Hive)
      final keysToDelete = _journalBox!.keys.where((key) {
        final e = _journalBox!.get(key);
        return e is Map &&
            e['user_id'] == userId &&
            e['id'] == journalId &&
            e['is_deleted'] == 1;
      }).toList();

      for (var key in keysToDelete) {
        await _journalBox!.delete(key);
      }
    }
    if (AppConfig.isDemo) return;
    try {
      await http
          .delete(Uri.parse('$apiBase/journals/$userId/$journalId/permanent'));
    } catch (e) {
      debugPrint("Permanent delete API error: $e");
    }
  }

  Future<List<Map<String, dynamic>>> getTrash(int userId) async {
    await purgeExpiredTrash();
    if (kIsWeb && _journalBox != null) {
      return _journalBox!.values
          .where(
              (e) => e is Map && e['user_id'] == userId && e['is_deleted'] == 1)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } else if (!kIsWeb) {
      return await _db.query(
        'journals',
        where: 'user_id = ? AND is_deleted = 1',
        whereArgs: [userId],
        orderBy: 'date DESC',
      );
    }
    return [];
  }

  Future<void> _saveLocalEntry(String key, Map<String, dynamic> entry) async {
    if (kIsWeb) {
      await _journalBox?.put(key, entry);
    } else {
      await _db.insert('journals', entry,
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<void> _queueSync(Map<String, dynamic> item) async {
    await _syncQueueBox?.add({
      ...item,
      'queued_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> syncPendingJournals() async {
    if (AppConfig.isDemo) return;
    if (_syncQueueBox == null || _syncQueueBox!.isEmpty) return;
    for (final key in _syncQueueBox!.keys.toList()) {
      final item = Map<String, dynamic>.from(_syncQueueBox!.get(key));
      try {
        final op = item['op'];
        final userId = item['user_id'];
        final entryId = item['entry_id'];
        if (op == 'insert') {
          final encrypted = await SecurityService.instance
              .encryptJournalText(item['text']?.toString() ?? '');
          final response = await http.post(
            Uri.parse('$apiBase/journals/$userId'),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "encrypted_journal": encrypted.toJson(),
              "mood": item['mood'],
              "image_path": item['image_path'],
            }),
          );
          if (response.statusCode < 200 || response.statusCode >= 300) continue;
        } else if (op == 'trash') {
          await http.delete(Uri.parse('$apiBase/journals/$userId/$entryId'));
        } else if (op == 'restore') {
          await http
              .post(Uri.parse('$apiBase/journals/$userId/$entryId/restore'));
        } else if (op == 'update') {
          final encrypted = await SecurityService.instance
              .encryptJournalText(item['text']?.toString() ?? '');
          await http.put(
            Uri.parse('$apiBase/journals/$userId/$entryId'),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              'encrypted_journal': encrypted.toJson(),
              'mood': item['mood'],
              'image_path': item['image_path'],
            }),
          );
        }
        await _syncQueueBox!.delete(key);
      } catch (e) {
        debugPrint("Sync queue item failed: $e");
      }
    }
  }

  Future<void> purgeExpiredTrash() async {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    if (kIsWeb && _journalBox != null) {
      final keysToDelete = _journalBox!.keys.where((key) {
        final entry = _journalBox!.get(key);
        if (entry is! Map || entry['is_deleted'] != 1) return false;
        final deletedAt =
            DateTime.tryParse(entry['deleted_at']?.toString() ?? '');
        return deletedAt != null && deletedAt.isBefore(cutoff);
      }).toList();
      for (final key in keysToDelete) {
        await _journalBox!.delete(key);
      }
    } else if (!kIsWeb) {
      await _db.delete(
        'journals',
        where: 'is_deleted = 1 AND deleted_at IS NOT NULL AND deleted_at < ?',
        whereArgs: [cutoff.toIso8601String()],
      );
    }
  }

  Future<void> _seedDemoJournals() async {
    if (_journalBox == null || _journalBox!.isNotEmpty) return;

    final now = DateTime.now();
    final samples = [
      {
        'id': 1001,
        'user_id': AppConfig.demoUserId,
        'text':
            'I finished an important milestone today. I feel proud, lighter, and excited about what comes next.',
        'mood': 'joy',
        'image_path': '',
        'date': now.subtract(const Duration(hours: 2)).toIso8601String(),
        'is_deleted': 0,
        'deleted_at': null,
        'sync_status': 'local-demo',
      },
      {
        'id': 1002,
        'user_id': AppConfig.demoUserId,
        'text':
            'The workload felt heavy, so I took a short walk and wrote down the three things I can control.',
        'mood': 'anxiety',
        'image_path': '',
        'date': now.subtract(const Duration(days: 1)).toIso8601String(),
        'is_deleted': 0,
        'deleted_at': null,
        'sync_status': 'local-demo',
      },
      {
        'id': 1003,
        'user_id': AppConfig.demoUserId,
        'text':
            'A quiet evening with family reminded me that small moments of connection matter.',
        'mood': 'love',
        'image_path': '',
        'date': now.subtract(const Duration(days: 2)).toIso8601String(),
        'is_deleted': 0,
        'deleted_at': null,
        'sync_status': 'local-demo',
      },
      {
        'id': 1004,
        'user_id': AppConfig.demoUserId,
        'text':
            'I was disappointed by the result, but I can see what I need to practice next.',
        'mood': 'sadness',
        'image_path': '',
        'date': now.subtract(const Duration(days: 4)).toIso8601String(),
        'is_deleted': 0,
        'deleted_at': null,
        'sync_status': 'local-demo',
      },
    ];

    for (final sample in samples) {
      await _journalBox!.put(sample['id'].toString(), sample);
    }
    await _sessionBox?.put('user_id', AppConfig.demoUserId);
  }
}
