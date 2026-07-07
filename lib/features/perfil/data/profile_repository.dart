import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

class ProfileRepository {
  ProfileRepository(this._client);

  final sb.SupabaseClient _client;

  Future<void> updateDatosPersonales({
    required String userId,
    required String nombre,
    String? apellidos,
  }) async {
    await _client.from('profiles').update({
      'nombre': nombre,
      'apellidos': apellidos,
    }).eq('id', userId);
  }

  /// Uploads the avatar to the `avatars/<userId>/avatar.<ext>` path (upsert),
  /// updates `profiles.foto_url` with a cache-busted public URL, and returns it.
  Future<String> uploadAvatar({
    required String userId,
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    final path = '$userId/avatar.$fileExtension';
    await _client.storage.from('avatars').uploadBinary(
          path,
          bytes,
          fileOptions: const sb.FileOptions(upsert: true),
        );

    final baseUrl = _client.storage.from('avatars').getPublicUrl(path);
    final fotoUrl = '$baseUrl?t=${DateTime.now().millisecondsSinceEpoch}';

    await _client.from('profiles').update({'foto_url': fotoUrl}).eq('id', userId);
    return fotoUrl;
  }

  Future<void> changePassword(String newPassword) async {
    await _client.auth.updateUser(sb.UserAttributes(password: newPassword));
  }
}
