import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../models/academia.dart';
import '../models/profile.dart';

class AuthRepository {
  AuthRepository(this._client);

  final sb.SupabaseClient _client;

  sb.Session? get currentSession => _client.auth.currentSession;

  Stream<sb.AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  /// Registers a student joining an existing (approved) academia. Profile
  /// creation happens atomically server-side (trigger `handle_new_user` reads
  /// this metadata), so there's no orphaned-auth-user window and the rol/estado
  /// are enforced by the server, not the client.
  Future<void> signUpAlumno({
    required String email,
    required String password,
    required String academiaId,
    required String nombre,
    String? apellidos,
  }) async {
    await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'flujo': 'unirse',
        'academia_id': academiaId,
        'nombre': nombre,
        if (apellidos != null && apellidos.isNotEmpty) 'apellidos': apellidos,
      },
    );
  }

  /// Registers a brand-new academia and its Dueño in a single atomic signup
  /// (see `signUpAlumno` and the `handle_new_user` trigger). The academia
  /// lands in `pending` and the Dueño in `pendiente_aprobacion`.
  Future<void> signUpDueno({
    required String email,
    required String password,
    required String nombreAcademia,
    String? direccion,
    String? telefono,
    String? emailContacto,
    required String nombre,
    String? apellidos,
  }) async {
    await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'flujo': 'registro_academia',
        'nombre_academia': nombreAcademia,
        if (direccion != null && direccion.isNotEmpty) 'direccion': direccion,
        if (telefono != null && telefono.isNotEmpty) 'telefono': telefono,
        if (emailContacto != null && emailContacto.isNotEmpty)
          'email_contacto': emailContacto,
        'nombre': nombre,
        if (apellidos != null && apellidos.isNotEmpty) 'apellidos': apellidos,
      },
    );
  }

  Future<void> signOut() => _client.auth.signOut();

  /// Academias already `approved`, for the "join an existing academia" picker.
  Future<List<AcademiaOption>> listAcademiasAprobadas() async {
    final rows = await _client.rpc('listar_academias_aprobadas') as List;
    return rows
        .map((r) => (id: r['id'] as String, nombre: r['nombre'] as String))
        .toList();
  }

  Future<Profile?> fetchProfile(String userId) async {
    final row = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
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
    final rows = await _client
        .from('academias')
        .select()
        .order('created_at', ascending: false);
    final academias = (rows as List)
        .map((r) => Academia.fromJson(r as Map<String, dynamic>))
        .toList();
    const ordenEstado = {'pending': 0, 'approved': 1, 'rejected': 2};
    academias.sort(
      (a, b) =>
          (ordenEstado[a.estado] ?? 3).compareTo(ordenEstado[b.estado] ?? 3),
    );
    return academias;
  }

  Future<void> aprobarAcademia(String academiaId) async {
    await _client.rpc(
      'aprobar_academia',
      params: {'p_academia_id': academiaId},
    );
  }

  Future<void> rechazarAcademia(String academiaId) async {
    await _client.rpc(
      'rechazar_academia',
      params: {'p_academia_id': academiaId},
    );
  }
}
