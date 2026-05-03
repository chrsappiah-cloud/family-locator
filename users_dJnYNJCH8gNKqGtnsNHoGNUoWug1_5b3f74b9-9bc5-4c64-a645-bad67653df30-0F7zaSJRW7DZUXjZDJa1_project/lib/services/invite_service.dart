import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'package:family_map/supabase/supabase_config.dart';

class FamilyInvite {
  final String id;
  final String familyId;
  final String code;
  final String? email;
  final String role;
  final DateTime? expiresAt;
  final int maxUses;
  final int usesCount;
  final DateTime? revokedAt;
  final DateTime createdAt;

  const FamilyInvite({
    required this.id,
    required this.familyId,
    required this.code,
    required this.email,
    required this.role,
    required this.expiresAt,
    required this.maxUses,
    required this.usesCount,
    required this.revokedAt,
    required this.createdAt,
  });

  factory FamilyInvite.fromJson(Map<String, dynamic> json) {
    DateTime? tryParse(dynamic v) => DateTime.tryParse(v?.toString() ?? '')?.toUtc();
    return FamilyInvite(
      id: json['id']?.toString() ?? '',
      familyId: json['family_id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      email: json['email']?.toString(),
      role: json['role']?.toString() ?? 'member',
      expiresAt: tryParse(json['expires_at']),
      maxUses: (json['max_uses'] as num?)?.toInt() ?? 1,
      usesCount: (json['uses_count'] as num?)?.toInt() ?? 0,
      revokedAt: tryParse(json['revoked_at']),
      createdAt: tryParse(json['created_at']) ?? DateTime.now().toUtc(),
    );
  }
}

class InviteService {
  static String _generateCode({int length = 10}) {
    // Avoid ambiguous chars; keeps codes easy to read over the phone.
    const alphabet = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';
    final rnd = Random.secure();
    return List.generate(length, (_) => alphabet[rnd.nextInt(alphabet.length)]).join();
  }

  static Future<FamilyInvite> createCodeInvite({
    required String familyId,
    Duration expiresIn = const Duration(days: 7),
    int maxUses = 1,
    String role = 'member',
  }) async {
    final uid = SupabaseConfig.auth.currentUser?.id;
    if (uid == null) throw StateError('Not authenticated.');

    final now = DateTime.now().toUtc();

    // Retry in the (rare) event of a uniqueness collision.
    for (var i = 0; i < 5; i++) {
      final code = _generateCode();
      try {
        final row = await SupabaseConfig.client
            .from('family_invites')
            .insert({
              'family_id': familyId,
              'created_by': uid,
              'code': code,
              'role': role,
              'expires_at': now.add(expiresIn).toIso8601String(),
              'max_uses': maxUses,
            })
            .select('*')
            .single();
        return FamilyInvite.fromJson(row);
      } catch (e) {
        debugPrint('Create invite attempt failed: $e');
      }
    }

    throw StateError('Failed to create invite. Please try again.');
  }

  static Future<void> revokeInvite({required String inviteId}) async {
    try {
      await SupabaseConfig.client.from('family_invites').update({'revoked_at': DateTime.now().toUtc().toIso8601String()}).eq('id', inviteId);
    } catch (e) {
      debugPrint('Failed to revoke invite: $e');
      rethrow;
    }
  }

  static Future<List<FamilyInvite>> listInvites({required String familyId}) async {
    try {
      final rows = await SupabaseConfig.client
          .from('family_invites')
          .select('*')
          .eq('family_id', familyId)
          .order('created_at', ascending: false);
      if (rows is! List) return const [];
      return rows.map((e) => FamilyInvite.fromJson((e as Map).cast<String, dynamic>())).toList();
    } catch (e) {
      debugPrint('Failed to list invites: $e');
      rethrow;
    }
  }

  /// Accepts an invite code and returns the family_id you joined.
  static Future<String> acceptInviteCode({required String code}) async {
    final uid = SupabaseConfig.auth.currentUser?.id;
    if (uid == null) throw StateError('Not authenticated.');

    final trimmed = code.trim().toUpperCase();
    if (trimmed.isEmpty) throw ArgumentError('Invite code is empty.');

    try {
      final res = await SupabaseConfig.client.rpc('accept_family_invite', params: {'p_code': trimmed});
      final familyId = res?.toString();
      if (familyId == null || familyId.isEmpty) throw StateError('Invite accepted but no family id returned.');

      // Set active family to the one just joined.
      try {
        await SupabaseConfig.client.from('users').update({'active_family_id': familyId}).eq('id', uid);
      } catch (e) {
        debugPrint('Failed setting active_family_id after accept: $e');
      }

      return familyId;
    } catch (e) {
      debugPrint('Accept invite failed: $e');
      rethrow;
    }
  }

  /// Sends an email invite via an Edge Function (recommended for production).
  ///
  /// Returns a shareable invite link even if email sending is disabled server-side.
  static Future<Uri> sendEmailInvite({
    required String familyId,
    required String email,
  }) async {
    try {
      final response = await SupabaseConfig.client.functions.invoke(
        'send_family_invite_email',
        body: {'family_id': familyId, 'email': email.trim()},
      );

      final body = response.data;
      if (body is Map && body['invite_link'] != null) {
        return Uri.parse(body['invite_link'].toString());
      }

      // Defensive fallback: sometimes `data` comes back as a JSON string.
      if (body is String) {
        final decoded = jsonDecode(body);
        if (decoded is Map && decoded['invite_link'] != null) {
          return Uri.parse(decoded['invite_link'].toString());
        }
      }

      throw StateError('Email invite function did not return invite_link.');
    } catch (e) {
      debugPrint('Failed sending email invite: $e');
      rethrow;
    }
  }
}
