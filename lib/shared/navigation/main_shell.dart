import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_mode.dart';
import '../../app/routes.dart';
import '../../app/theme/color_tokens.dart';
import '../../core/auth/auth_state.dart';
import '../../core/models/profile.dart';

/// Estructura de la app autenticada: **barra inferior fija**, con dos juegos
/// de destinos según el modo (ver [AppMode]).
///
/// Antes había un cajón lateral con doce destinos mezclados: quien entrena y
/// quien gestiona veían la misma lista. Separarlo en dos modos, como hace
/// MAAT, deja cada barra en cuatro destinos y hace evidente en qué papel
/// estás en cada momento.
/// Ancho máximo del contenido. Por encima de esto no se gana legibilidad:
/// una línea de texto muy larga se lee peor, no mejor.
const double _anchoMaximo = 560;

class MainShell extends ConsumerWidget {
  const MainShell({required this.child, super.key});

  final Widget child;

  /// Lo que ve cualquiera que venga a entrenar.
  static const _entrenamiento = <_Destino>[
    _Destino(Routes.inicio, 'Inicio', Icons.home_outlined, Icons.home),
    _Destino(
      Routes.estadisticas,
      'Estadísticas',
      Icons.bar_chart_outlined,
      Icons.bar_chart,
    ),
    _Destino(
      Routes.novedades,
      'Novedades',
      Icons.campaign_outlined,
      Icons.campaign,
    ),
    _Destino(Routes.perfil, 'Perfil', Icons.person_outline, Icons.person),
  ];

  /// Lo que ve quien lleva la academia. El hueco de "Miembros" se añadirá
  /// aquí cuando exista la gestión de alumnos.
  static const _gestor = <_Destino>[
    _Destino(Routes.inicio, 'Hoy', Icons.today_outlined, Icons.today),
    _Destino(
      Routes.herramientas,
      'Herramientas',
      Icons.handyman_outlined,
      Icons.handyman,
    ),
    _Destino(
      Routes.novedades,
      'Novedades',
      Icons.campaign_outlined,
      Icons.campaign,
    ),
    _Destino(
      Routes.academia,
      'Academia',
      Icons.apartment_outlined,
      Icons.apartment,
    ),
  ];

  /// El Administrador de plataforma no pertenece a ninguna academia: no
  /// entrena ni gestiona una, así que no tiene modos.
  static const _administrador = <_Destino>[
    _Destino(
      Routes.admin,
      'Academias',
      Icons.verified_user_outlined,
      Icons.verified_user,
    ),
    _Destino(Routes.perfil, 'Perfil', Icons.person_outline, Icons.person),
  ];

  static List<_Destino> _destinosPara(Profile? profile, AppMode modo) {
    if (profile?.isAdministrador ?? false) return _administrador;
    return modo == AppMode.gestor ? _gestor : _entrenamiento;
  }

  /// Pantallas que cuelgan de un destino de la barra. Sin esto, estando en
  /// Equipo o en Cobros no coincidía ninguna ruta y la barra marcaba el
  /// primer destino: parecía que estabas en «Hoy» cuando no lo estabas.
  static const _rutaPadre = <String, String>{
    Routes.equipo: Routes.academia,
    Routes.ajustesReservas: Routes.academia,
    Routes.tarifas: Routes.herramientas,
  };

  /// Solo profesor y dueño pueden cambiar de modo: son los únicos que hacen
  /// las dos cosas.
  static bool _puedeCambiarModo(Profile? profile) =>
      profile != null && (profile.isDueno || profile.isProfesor);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).value;
    final modo = ref.watch(appModeProvider);
    final location = GoRouterState.of(context).matchedLocation;

    final destinos = _destinosPara(profile, modo);
    final rutaMarcada = destinos.any((d) => d.ruta == location)
        ? location
        : (_rutaPadre[location] ?? location);
    final indiceActual = destinos.indexWhere((d) => d.ruta == rutaMarcada);
    final cambiaModo = _puedeCambiarModo(profile);

    return Scaffold(
      // La app está pensada para el móvil. En el navegador de un portátil se
      // estiraba de lado a lado y todo parecía enorme y vacío: las tarjetas
      // ocupaban 1900 px de ancho y el texto quedaba perdido. Se limita el
      // ancho en un único sitio para que valga en todas las pantallas.
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _anchoMaximo),
            child: child,
          ),
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        // Por delante: la barra pinta su propio fondo encima y, si el borde
        // fuera por detrás, la línea solo se vería en el trozo del botón de
        // modo. Quedaba una rayita suelta a la derecha.
        position: DecorationPosition.foreground,
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          children: [
            Expanded(
              child: NavigationBar(
                selectedIndex: indiceActual < 0 ? 0 : indiceActual,
                onDestinationSelected: (i) {
                  final destino = destinos[i];
                  if (destino.ruta != location) context.go(destino.ruta);
                },
                destinations: [
                  for (final d in destinos)
                    NavigationDestination(
                      icon: Icon(d.icono),
                      selectedIcon: Icon(d.iconoActivo),
                      label: d.etiqueta,
                      tooltip: d.etiqueta,
                    ),
                ],
              ),
            ),
            // El cambio de modo va en la barra —flotando tapaba «Reservar
            // plaza», el final de Perfil y el propio «Crear clase»— pero
            // **no es un destino**: no es un sitio donde estás, es una
            // acción. Metido como destino más, la barra lo pintaba siempre
            // con el gris de «no estás aquí» y parecía deshabilitado. Va
            // aparte, en tinta, para que se vea que se puede pulsar.
            if (cambiaModo)
              _BotonModo(
                modo: modo,
                onTap: () {
                  final nuevo = ref.read(appModeProvider.notifier).alternar();
                  context.go(_destinosPara(profile, nuevo).first.ruta);
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// El sitio de la barra que cambia de modo.
///
/// No usa `NavigationDestination` a propósito: aquello lo pintaba con el gris
/// de destino inactivo y parecía apagado. Aquí va en tinta, como lo que es —
/// algo que se puede pulsar siempre.
class _BotonModo extends StatelessWidget {
  const _BotonModo({required this.modo, required this.onTap});

  final AppMode modo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: modo.etiquetaCambio,
      child: Tooltip(
        message: modo.etiquetaCambio,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            // Mismo alto que la barra, y un ancho parecido al de un destino
            // para que no rompa el ritmo de la fila.
            width: 76,
            height: 68,
            child: Padding(
              // La barra no centra su contenido igual que un Column normal:
              // sin este hueco, el icono y el texto quedaban 5 px más altos
              // que los de al lado y se notaba. Hay una prueba que lo mide.
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.swap_horiz, size: 22, color: AppColors.ink),
                  const SizedBox(height: 4),
                  Text(
                    modo.etiquetaCortaCambio,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Destino {
  const _Destino(this.ruta, this.etiqueta, this.icono, this.iconoActivo);

  final String ruta;
  final String etiqueta;
  final IconData icono;
  final IconData iconoActivo;
}
