import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/auth/auth_state.dart';

/// Los dos modos de la app, como en MAAT: se entrena o se gestiona, nunca
/// las dos cosas a la vez en la misma pantalla.
///
/// Un alumno solo tiene [entrenamiento]. Un profesor o dueño alterna entre
/// los dos con el botón del pie de pantalla, porque también entrena.
enum AppMode {
  entrenamiento,
  gestor;

  String get etiqueta => switch (this) {
    AppMode.entrenamiento => 'Entrenamiento',
    AppMode.gestor => 'Gestor',
  };

  /// Texto del botón que lleva al *otro* modo.
  String get etiquetaCambio => switch (this) {
    AppMode.entrenamiento => 'Cambiar a Gestor',
    AppMode.gestor => 'Cambiar a Entrenamiento',
  };

  AppMode get contrario => switch (this) {
    AppMode.entrenamiento => AppMode.gestor,
    AppMode.gestor => AppMode.entrenamiento,
  };
}

/// Modo activo. Vive solo durante la sesión: al volver a abrir la app se
/// entra siempre en Entrenamiento, que es lo que hace la mayoría.
class AppModeNotifier extends Notifier<AppMode> {
  @override
  AppMode build() => AppMode.entrenamiento;

  /// Salta al otro modo y devuelve el nuevo, para poder navegar acto seguido.
  AppMode alternar() => state = state.contrario;
}

final appModeProvider = NotifierProvider<AppModeNotifier, AppMode>(
  AppModeNotifier.new,
);

/// ¿La pantalla debe comportarse como herramienta de gestión?
///
/// **Esta es la pregunta que deben hacerse las pantallas, no «¿qué rol
/// tiene?».** Un dueño también entrena: cuando está en modo Entrenamiento
/// quiere apuntarse a clase y ver su cuota, igual que cualquier alumno, y no
/// quiere el botón de crear clases estorbando.
///
/// Confundir rol con modo fue el fallo del rediseño: las pantallas decidían
/// por rol, así que a un dueño se le daba la versión de gestión siempre y se
/// quedaba sin poder reservar.
///
/// Es `true` solo si se dan las dos cosas: el modo activo es [AppMode.gestor]
/// **y** el rol tiene permiso para gestionar. Lo segundo no sobra: el modo lo
/// elige el cliente, y el permiso no puede depender de eso.
final enModoGestionProvider = Provider<bool>((ref) {
  final profile = ref.watch(currentProfileProvider).value;
  if (profile == null) return false;
  final puedeGestionar =
      profile.isProfesor || profile.isDueno || profile.isAdministrador;
  return puedeGestionar && ref.watch(appModeProvider) == AppMode.gestor;
});
