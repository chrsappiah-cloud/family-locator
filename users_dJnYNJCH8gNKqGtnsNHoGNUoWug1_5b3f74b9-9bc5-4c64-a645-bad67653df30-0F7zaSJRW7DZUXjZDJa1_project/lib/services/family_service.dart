import 'package:flutter/foundation.dart';

import 'package:family_map/supabase/supabase_config.dart';

class FamilyService {
  /// Ensures the current user has at least one family and is a member of it.
  /// Returns the family_id.
  static Future<String> ensureDefaultFamily() async {
    final uid = SupabaseConfig.auth.currentUser?.id;
    if (uid == null) throw StateError('Not authenticated.');

    // 0) If the user has an active family, prefer it.
    try {
      final profile = await SupabaseConfig.client.from('users').select('active_family_id').eq('id', uid).maybeSingle();
      final activeFamilyId = profile?['active_family_id']?.toString();
      if (activeFamilyId != null && activeFamilyId.isNotEmpty) {
        final membership = await SupabaseConfig.client
            .from('family_members')
            .select('family_id')
            .eq('user_id', uid)
            .eq('family_id', activeFamilyId)
            .limit(1);
        if (membership is List && membership.isNotEmpty) return activeFamilyId;
      }
    } catch (e) {
      debugPrint('Failed reading users.active_family_id: $e');
    }

    // 1) If user belongs to any family, use the first.
    try {
      final existing = await SupabaseConfig.client
          .from('family_members')
          .select('family_id')
          .eq('user_id', uid)
          .limit(1);
      if (existing is List && existing.isNotEmpty) {
        final fid = existing.first['family_id']?.toString();
        if (fid != null && fid.isNotEmpty) return fid;
      }
    } catch (e) {
      debugPrint('Failed reading family_members: $e');
      rethrow;
    }

    // 2) Create a new family owned by the current user.
    final created = await SupabaseConfig.client
        .from('families')
        .insert({'name': 'My Family', 'owner_id': uid})
        .select('id')
        .single();
    final familyId = created['id']?.toString();
    if (familyId == null || familyId.isEmpty) throw StateError('Failed to create family.');

    // 3) Add self to the family.
    await SupabaseConfig.client.from('family_members').insert({
      'family_id': familyId,
      'user_id': uid,
      'role': 'owner',
    });

    // 4) Mark this as active.
    try {
      await SupabaseConfig.client.from('users').update({'active_family_id': familyId}).eq('id', uid);
    } catch (e) {
      debugPrint('Failed updating active_family_id: $e');
    }

    return familyId;
  }
}
