import 'dart:convert';
import 'dart:math';

import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import '../models/journal_analysis.dart';

class SecurityService {
  SecurityService._();
  static final SecurityService instance = SecurityService._();

  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  static const String _journalKeyName = 'nuromood_journal_aes_key_v1';

  Future<bool> authenticateWithBiometrics() async {
    final canCheck = await _localAuth.canCheckBiometrics || await _localAuth.isDeviceSupported();
    if (!canCheck) return false;
    return _localAuth.authenticate(
      localizedReason: 'Unlock your private NeuroMood journal',
      options: const AuthenticationOptions(
        biometricOnly: false,
        stickyAuth: true,
      ),
    );
  }

  Future<EncryptedJournal> encryptJournalText(String plainText) async {
    final key = await _getOrCreateJournalKey();
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    return EncryptedJournal(
      ciphertext: encrypted.base64,
      iv: iv.base64,
      keyVersion: 1,
    );
  }

  Future<encrypt.Key> _getOrCreateJournalKey() async {
    final existing = await _secureStorage.read(key: _journalKeyName);
    if (existing != null) return encrypt.Key.fromBase64(existing);

    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    final encoded = base64Encode(bytes);
    await _secureStorage.write(key: _journalKeyName, value: encoded);
    return encrypt.Key.fromBase64(encoded);
  }
}
