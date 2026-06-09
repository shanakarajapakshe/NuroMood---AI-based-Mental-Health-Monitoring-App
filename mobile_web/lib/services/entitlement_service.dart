import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../app_config.dart';

class UserEntitlement {
  final String tier;
  final bool isPremium;
  final int chartsDays;
  final bool voiceJournaling;
  final bool clinicalExport;
  final bool advancedTriggers;

  const UserEntitlement({
    required this.tier,
    required this.isPremium,
    required this.chartsDays,
    required this.voiceJournaling,
    required this.clinicalExport,
    required this.advancedTriggers,
  });

  static const free = UserEntitlement(
    tier: 'free',
    isPremium: false,
    chartsDays: 7,
    voiceJournaling: false,
    clinicalExport: false,
    advancedTriggers: false,
  );

  factory UserEntitlement.fromJson(Map<String, dynamic> json) {
    final features = Map<String, dynamic>.from(json['features'] ?? const {});
    return UserEntitlement(
      tier: json['tier']?.toString() ?? 'free',
      isPremium: json['is_premium'] == true,
      chartsDays: (features['charts_days'] as num?)?.toInt() ?? 7,
      voiceJournaling: features['voice_journaling'] == true,
      clinicalExport: features['clinical_export'] == true,
      advancedTriggers: features['advanced_triggers'] == true,
    );
  }
}

class EntitlementService {
  EntitlementService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final String apiBase = 'http://127.0.0.1:5000';

  Future<UserEntitlement> getEntitlement(int userId) async {
    if (AppConfig.isDemo) return UserEntitlement.free;
    try {
      final response =
          await _client.get(Uri.parse('$apiBase/entitlements/$userId'));
      if (response.statusCode == 200) {
        return UserEntitlement.fromJson(
            Map<String, dynamic>.from(jsonDecode(response.body)));
      }
    } catch (e) {
      debugPrint('Entitlement fetch failed: $e');
    }
    return UserEntitlement.free;
  }
}
