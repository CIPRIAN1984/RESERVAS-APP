import 'package:flutter_riverpod/flutter_riverpod.dart';

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
