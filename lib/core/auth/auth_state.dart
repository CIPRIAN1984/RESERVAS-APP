import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../models/academia.dart';
import '../models/profile.dart';
import '../supabase/supabase_client.dart';
import 'auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(AppSupabase.client);
});

/// Raw Supabase auth stream (sign-in/sign-out/token refresh events).
final authStateChangesProvider = StreamProvider<sb.AuthState>((ref) {
  return ref.watch(authRepositoryProvider).onAuthStateChange;
});

/// Null when signed out. Falls back to the current session so the very first
/// build (before the stream emits) already reflects a persisted session.
final currentUserIdProvider = Provider<String?>((ref) {
  final event = ref.watch(authStateChangesProvider).value;
  return event?.session?.user.id ?? AppSupabase.client.auth.currentUser?.id;
});

/// The signed-in user's `profiles` row: carries rol, academia_id and estado —
/// everything the router guards and role-conditional UI need.
final currentProfileProvider = FutureProvider<Profile?>((ref) async {
  ref.watch(authStateChangesProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  return ref.watch(authRepositoryProvider).fetchProfile(userId);
});

/// The academia the current user belongs to (null for Administrador).
final currentAcademiaProvider = FutureProvider<Academia?>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile?.academiaId == null) return null;
  return ref.watch(authRepositoryProvider).fetchAcademia(profile!.academiaId!);
});
