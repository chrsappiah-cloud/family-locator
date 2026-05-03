import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:family_map/supabase/supabase_config.dart';

class FamilyLocationSample {
  final String userId;
  final String? familyId;
  final double latitude;
  final double longitude;
  final DateTime recordedAt;

  const FamilyLocationSample({
    required this.userId,
    required this.familyId,
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
  });

  factory FamilyLocationSample.fromJson(Map<String, dynamic> json) {
    return FamilyLocationSample(
      userId: json['user_id']?.toString() ?? '',
      familyId: json['family_id']?.toString(),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      recordedAt: DateTime.tryParse(json['recorded_at']?.toString() ?? '')?.toUtc() ?? DateTime.now().toUtc(),
    );
  }
}

class RealtimeLocationService {
  RealtimeChannel? _channel;
  final _controller = StreamController<FamilyLocationSample>.broadcast();

  Stream<FamilyLocationSample> get samples => _controller.stream;

  Future<void> start({required String familyId}) async {
    await stop();

    _channel = SupabaseConfig.client.channel('family_locations:$familyId');

    _channel!
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'user_locations',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'family_id', value: familyId),
          callback: (payload) {
            try {
              final record = payload.newRecord;
              if (record.isEmpty) return;
              _controller.add(FamilyLocationSample.fromJson(record));
            } catch (e) {
              debugPrint('Realtime decode failed: $e');
            }
          },
        )
        .subscribe((status, error) {
          if (error != null) debugPrint('Realtime subscribe error: $error');
          debugPrint('Realtime status: $status');
        });
  }

  Future<void> stop() async {
    if (_channel != null) {
      try {
        await SupabaseConfig.client.removeChannel(_channel!);
      } catch (e) {
        debugPrint('Failed removing realtime channel: $e');
      }
      _channel = null;
    }
  }

  Future<void> publishMyLocation({
    required String familyId,
    required double latitude,
    required double longitude,
    double? accuracyM,
    double? headingDeg,
    double? speedMps,
    DateTime? recordedAt,
  }) async {
    final uid = SupabaseConfig.auth.currentUser?.id;
    if (uid == null) throw StateError('Not authenticated.');

    final now = (recordedAt ?? DateTime.now().toUtc()).toIso8601String();
    await SupabaseConfig.client.from('user_locations').insert({
      'user_id': uid,
      'family_id': familyId,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy_m': accuracyM,
      'heading_deg': headingDeg,
      'speed_mps': speedMps,
      'recorded_at': now,
      'updated_at': now,
    });
  }

  Future<void> dispose() async {
    await stop();
    await _controller.close();
  }
}
