import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'package:family_map/auth/auth_manager.dart';
import 'package:family_map/models/app_user.dart';
import 'package:family_map/supabase/supabase_config.dart';

/// Supabase implementation of [AuthManager].
///
/// Notes:
/// - We keep a lightweight cached [AppUser] for app usage.
/// - The public `users` table is expected to exist (see `lib/supabase/*.sql`).
class SupabaseAuthManager extends AuthManager with EmailSignInManager {
  AppUser? _currentUser;
  @override
  AppUser? get currentUser => _currentUser;

  @override
  Stream<AppUser?> authStateChanges() {
    return SupabaseConfig.auth.onAuthStateChange.asyncMap((event) async {
      final session = event.session;
      if (session?.user == null) {
        _currentUser = null;
        return null;
      }
      try {
        _currentUser = await _ensureUserProfile(session!.user);
      } catch (e) {
        debugPrint('Failed to load/ensure user profile: $e');
        _currentUser = _fallbackFromAuthUser(session!.user);
      }
      return _currentUser;
    });
  }

  @override
  Future<AppUser> signInWithEmail({
    required BuildContext context,
    required String email,
    required String password,
  }) async {
    final res = await SupabaseConfig.auth.signInWithPassword(email: email, password: password);
    final user = res.user;
    if (user == null) throw StateError('Supabase sign-in succeeded but no user returned.');

    // Important: Auth can succeed even if your profile table/RLS is misconfigured.
    // Never block sign-in on profile upsert/select.
    _currentUser = _fallbackFromAuthUser(user);
    try {
      _currentUser = await _ensureUserProfile(user);
    } catch (e) {
      debugPrint('User profile ensure failed after sign-in; continuing with fallback user: $e');
    }
    return _currentUser!;
  }

  @override
  Future<AppUser> createAccountWithEmail({
    required BuildContext context,
    required String email,
    required String password,
  }) async {
    final res = await SupabaseConfig.auth.signUp(email: email, password: password);
    final user = res.user;
    if (user == null) {
      // If email confirmations are enabled, Supabase may not return a user/session the way you expect.
      // We fail with a clear message so the UI can instruct the user what to do next.
      throw StateError(
        'Account created but no user returned. If email confirmations are enabled, check your inbox and confirm before signing in.',
      );
    }

    _currentUser = _fallbackFromAuthUser(user);
    try {
      _currentUser = await _ensureUserProfile(user);
    } catch (e) {
      debugPrint('User profile ensure failed after sign-up; continuing with fallback user: $e');
    }
    return _currentUser!;
  }

  @override
  Future<void> resetPassword({
    required BuildContext context,
    required String email,
  }) async {
    // You can provide a redirectTo for deep links; leaving null is OK for basic setup.
    await SupabaseConfig.auth.resetPasswordForEmail(email);
  }

  @override
  Future<void> signOut() async {
    await SupabaseConfig.auth.signOut();
    _currentUser = null;
  }

  @override
  Future<void> deleteAccount({required BuildContext context}) async {
    // Client-side deletion of auth user requires an admin API/service role.
    // Typical approach: call an Edge Function that uses service_role to delete the user.
    throw UnimplementedError(
      'Account deletion requires a Supabase Edge Function (service role).',
    );
  }

  @override
  Future<AppUser> refreshCurrentUser() async {
    final authUser = SupabaseConfig.auth.currentUser;
    if (authUser == null) throw StateError('No authenticated user.');
    _currentUser = await _ensureUserProfile(authUser);
    return _currentUser!;
  }

  Future<AppUser> _ensureUserProfile(sb.User authUser) async {
    // Upsert a user row so other tables can FK against public.users.
    final now = DateTime.now().toUtc();
    try {
      await SupabaseConfig.client.from('users').upsert({
        'id': authUser.id,
        'email': authUser.email,
        'updated_at': now.toIso8601String(),
        // created_at default handled server-side; but include for first insert.
        'created_at': now.toIso8601String(),
      });
    } catch (e) {
      // Most common cause: RLS not allowing upserts/selects on public.users.
      // We rethrow so callers can decide whether to block (we never block auth).
      debugPrint('Failed to upsert into public.users (RLS?): $e');
      rethrow;
    }

    final row = await SupabaseConfig.client
        .from('users')
        .select('*')
        .eq('id', authUser.id)
        .maybeSingle();

    if (row == null) return _fallbackFromAuthUser(authUser);
    return AppUser.fromJson(row);
  }

  AppUser _fallbackFromAuthUser(sb.User u) {
    final now = DateTime.now().toUtc();
    return AppUser(id: u.id, email: u.email, displayName: null, createdAt: now, updatedAt: now);
  }
}
