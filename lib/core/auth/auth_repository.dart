import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../models/academia.dart';
import '../models/profile.dart';
import '../models/rol.dart';

class AuthRepository {
  AuthRepository(this._client);

  final sb.SupabaseClient _client;

  sb.Session? get currentSession => _client.auth.currentSession;

  Stream<sb.AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  /// Returns the new auth user id.
  Future<String> signUp({required String email, required String password}) async {
    final res = await _client.auth.signUp(email: email, password: password);
    final userId = res.user?.id;
    if (userId == null) {
      throw StateError('El registro no devolvió un usuario válido.');
    }
    return userId;
  }

  Future<void> signOut() => _client.auth.signOut();

  /// Academias already `approved`, for the "join an existing academia" picker.
  Future<List<AcademiaOption>> listAcademiasAprobadas() async {
    final rows = await _client.rpc('listar_academias_aprobadas') as List;
    return rows
        .map((r) => (id: r['id'] as String, nombre: r['nombre'] as String))
        .toList();
  }

  /// Creates the profile row for a student/teacher joining an existing (approved) academia.
  Future<void> crearPerfilEnAcademiaExistente({
    required String userId,
    required String academiaId,
    required Rol rol,
    required String nombre,
    String? apellidos,
  }) async {
    await _client.from('profiles').insert({
      'id': userId,
      'academia_id': academiaId,
      'rol': rol.value,
      'nombre': nombre,
      'apellidos': apellidos,
      'estado': 'activo',
    });
  }

  /// Registers a brand-new academia (goes to `pending`) and its Dueño profile,
  /// which stays `pendiente_aprobacion` until the platform Administrador approves it.
  Future<void> registrarAcademiaYPerfilDueno({
    required String userId,
    required String nombreAcademia,
    String? direccion,
    String? telefono,
    String? emailContacto,
    required String nombre,
    String? apellidos,
  }) async {
    final academia = await _client
        .from('academias')
        .insert({
          'nombre': nombreAcademia,
          'direccion': direccion,
          'telefono': telefono,
          'email_contacto': emailContacto,
          'estado': 'pending',
          'created_by': userId,
        })
        .select()
        .single();

    await _client.from('profiles').insert({
      'id': userId,
      'academia_id': academia['id'],
      'rol': Rol.dueno.value,
      'nombre': nombre,
      'apellidos': apellidos,
      'estado': 'pendiente_aprobacion',
    });
  }

  Future<Profile?> fetchProfile(String userId) async {
    final row =
        await _client.from('profiles').select().eq('id', userId).maybeSingle();
    if (row == null) return null;
    return Profile.fromJson(row);
  }

  Future<Academia?> fetchAcademia(String academiaId) async {
    final row = await _client
        .from('academias')
        .select()
        .eq('id', academiaId)
        .maybeSingle();
    if (row == null) return null;
    return Academia.fromJson(row);
  }

  /// Administrador-only: every academia on the platform, pending ones first.
  Future<List<Academia>> listAcademiasTodas() async {
    final rows = await _client.from('academias').select().order('created_at', ascending: false);
    final academias = (rows as List)
        .map((r) => Academia.fromJson(r as Map<String, dynamic>))
        .toList();
    const ordenEstado = {'pending': 0, 'approved': 1, 'rejected': 2};
    academias.sort((a, b) => (ordenEstado[a.estado] ?? 3).compareTo(ordenEstado[b.estado] ?? 3));
    return academias;
  }

  Future<void> aprobarAcademia(String academiaId) async {
    await _client.rpc('aprobar_academia', params: {'p_academia_id': academiaId});
  }

  Future<void> rechazarAcademia(String academiaId) async {
    await _client
        .from('academias')
        .update({'estado': 'rejected'})
        .eq('id', academiaId);
  }
}
