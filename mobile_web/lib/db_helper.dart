import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:path/path.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';



class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  factory DBHelper() => _instance;
  DBHelper._internal();

  late Database _db;
final String apiBase = "http://192.168.1.144:5000";



  int? _currentUserId;

  Box? _journalBox;
  Box? _sessionBox;

  /// Initialize DB (SQLite for mobile/desktop, Hive for web)
  Future<void> init() async {
    await Hive.initFlutter();
    _journalBox = await Hive.openBox('journals');
    _sessionBox = await Hive.openBox('session');

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
              is_deleted INTEGER DEFAULT 0
            )
          ''');
        },
      );
    }

    // Load current user session
    await _loadCurrentUser();
  }

  // ------------------- Session -------------------

  Future<void> _loadCurrentUser() async {
    // Check Hive first
    final hiveUser = _sessionBox?.get('user_id');
    if (hiveUser != null) {
      _currentUserId = hiveUser is int ? hiveUser : int.tryParse(hiveUser.toString());
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
          _currentUserId = rawUserId is int ? rawUserId : int.tryParse(rawUserId.toString());
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
        await getJournals(userId, refresh: true);

        return userId;
      }
    } catch (e) {
      debugPrint("Login error: $e");
    }
    return null;
  }

  // ------------------- Journals -------------------

  Future<List<Map<String, dynamic>>> getJournals(int userId, {bool refresh = false}) async {
    List<Map<String, dynamic>> journals = [];

    if (!refresh) {
      if (kIsWeb && _journalBox != null && _journalBox!.isNotEmpty) {
        journals = _journalBox!.values
            .where((e) => e is Map && e['user_id'] == userId && e['is_deleted'] == 0)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        if (journals.isNotEmpty) return journals;
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

    // Fetch from API
    try {
      final response = await http.get(Uri.parse('$apiBase/journals/$userId'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        journals = data.map((e) => Map<String, dynamic>.from(e)).toList();

        if (kIsWeb) {
          await _journalBox?.clear();
          for (var entry in journals) await _journalBox?.put(entry['id'].toString(), entry);
        } else {
          for (var entry in journals) {
            await _db.insert('journals', entry, conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
      }
    } catch (e) {
      debugPrint("Fetch journals API error: $e");
    }

    return journals;
  }

  Future<void> insertJournal(int userId, String text, String mood, {String? image}) async {
    final id = DateTime.now().millisecondsSinceEpoch;
    final entry = {
      'id': id,
      'user_id': userId,
      'text': text,
      'mood': mood,
      'image_path': image ?? '',
      'date': DateTime.now().toIso8601String(),
      'is_deleted': 0,
    };

    if (kIsWeb) {
      await _journalBox?.put(id.toString(), entry);
    } else {
      await _db.insert('journals', entry);
    }

    try {
await http.post(
  Uri.parse('$apiBase/journals/$userId'),
  headers: {"Content-Type": "application/json"},
  body: jsonEncode({"text": text, "mood": mood, "image_path": image}),  // ✅ fixed
);

    } catch (e) {
      debugPrint("Insert journal API error: $e");
    }
  }

  Future<void> moveToTrash(int userId, int entryId) async {
    await _updateJournalStatus(userId, entryId, 1);
    try {
      await http.delete(Uri.parse('$apiBase/journals/$userId/$entryId'));
    } catch (e) {
      debugPrint("Move to trash API error: $e");
    }
  }

  Future<void> restoreFromTrash(int userId, int entryId) async {
    await _updateJournalStatus(userId, entryId, 0);
    try {
      await http.post(Uri.parse('$apiBase/journals/$userId/$entryId/restore'));
    } catch (e) {
      debugPrint("Restore API error: $e");
    }
  }

  Future<List<Map<String, dynamic>>> getJournalsByDate(int userId, String date, {bool refresh = false}) async {
  List<Map<String, dynamic>> journals = [];

  // Check local cache first
  if (!refresh) {
    if (kIsWeb && _journalBox != null) {
      journals = _journalBox!.values
          .where((e) => e is Map && e['user_id'] == userId && e['is_deleted'] == 0 && (e['date'] as String).startsWith(date))
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

  // Fetch from API
  try {
    final response = await http.get(Uri.parse('$apiBase/journals/$userId/date/$date'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List;
      journals = data.map((e) => Map<String, dynamic>.from(e)).toList();

      // Save locally
      if (kIsWeb) {
        for (var entry in journals) await _journalBox?.put(entry['id'].toString(), entry);
      } else {
        for (var entry in journals) {
          await _db.insert('journals', entry, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    }
  } catch (e) {
    debugPrint("Fetch journals by date API error: $e");
  }

  return journals;
}


  Future<void> _updateJournalStatus(int userId, int entryId, int isDeleted) async {
    if (kIsWeb) {
      final entry = _journalBox?.get(entryId.toString());
      if (entry != null) {
        final updated = Map<String, dynamic>.from(entry);
        updated['is_deleted'] = isDeleted;
        await _journalBox?.put(entryId.toString(), updated);
      }
    } else {
      await _db.update(
        'journals',
        {'is_deleted': isDeleted},
        where: 'user_id = ? AND id = ?',
        whereArgs: [userId, entryId],
      );
    }
  }
// ------------------- Update Journal -------------------
Future<void> updateJournal(int userId, int entryId, String text, String mood, {String? image}) async {
  final updatedEntry = {
    'text': text,
    'mood': mood,
    'image_path': image ?? '',
    'date': DateTime.now().toIso8601String(),
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
  try {
   await http.put(
  Uri.parse('$apiBase/journals/$userId/$entryId'),
  headers: {"Content-Type": "application/json"},
  body: jsonEncode({
    'text': text,
    'mood': mood,
    'image_path': image   // ✅ correct
  }),
);

  } catch (e) {
    debugPrint("Update journal API error: $e");
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
}


  Future<List<Map<String, dynamic>>> getTrash(int userId) async {
    if (kIsWeb && _journalBox != null) {
      return _journalBox!.values
          .where((e) => e is Map && e['user_id'] == userId && e['is_deleted'] == 1)
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
}
