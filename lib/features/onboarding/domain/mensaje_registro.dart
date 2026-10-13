/// Lo que dice Supabase al rechazar un registro, en castellano y sin jerga.
///
/// Antes se enseñaba el texto tal cual («User already registered»): en
/// inglés y sin decir qué hacer (auditoría del 09/10/2026).
String mensajeRegistro(String mensajeServidor) {
  final m = mensajeServidor.toLowerCase();
  if (m.contains('already registered') || m.contains('already exists')) {
    return 'Ya hay una cuenta con ese correo. Inicia sesión o recupera la '
        'contraseña.';
  }
  if (m.contains('weak') || m.contains('pwned') || m.contains('leaked')) {
    return 'Esa contraseña aparece en filtraciones conocidas de internet. '
        'Elige otra.';
  }
  if (m.contains('password')) {
    return 'La contraseña no es válida: usa al menos 6 caracteres.';
  }
  if (m.contains('invalid format') || m.contains('email address')) {
    return 'Ese correo no es válido. Revísalo.';
  }
  if (m.contains('rate limit')) {
    return 'Demasiados intentos seguidos. Espera unos minutos y vuelve a '
        'probar.';
  }
  return 'No se ha podido completar el registro. Inténtalo de nuevo.';
}

/// Lo que se le dice cuando el registro ha ido bien pero falta confirmar el
/// correo: sin esto la pantalla se quedaba igual y parecía que no había
/// pasado nada.
String textoRevisaTuCorreo(String correo) =>
    'Te hemos enviado un correo a $correo. Ábrelo y pulsa el enlace para '
    'activar tu cuenta; después ya puedes entrar. Si no lo ves en unos '
    'minutos, mira en la carpeta de spam.';
