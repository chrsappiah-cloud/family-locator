import 'package:flutter/material.dart';

import 'package:family_map/models/app_user.dart';

/// Authentication contract for the app.
///
/// This is intentionally provider-agnostic (Supabase/Firebase/etc.).
abstract class AuthManager {
  Stream<AppUser?> authStateChanges();

  AppUser? get currentUser;

  Future<void> signOut();
  Future<void> deleteAccount({required BuildContext context});

  Future<AppUser> refreshCurrentUser();
}

mixin EmailSignInManager on AuthManager {
  Future<AppUser> signInWithEmail({
    required BuildContext context,
    required String email,
    required String password,
  });

  Future<AppUser> createAccountWithEmail({
    required BuildContext context,
    required String email,
    required String password,
  });

  Future<void> resetPassword({
    required BuildContext context,
    required String email,
  });
}
