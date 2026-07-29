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
    _Destino(
      Routes.solicitudesCambioEscuela,
      'Cambios',
      Icons.swap_horiz_outlined,
      Icons.swap_horiz,
    ),
    _Destino(Routes.perfil, 'Perfil', Icons.person_outline, Icons.person),
  ];

  static List<_Destino> _destinosPara(Profile? profile, AppMode modo) {
    if (profile?.isAdministrador ?? false) return _administrador;
    return modo == AppMode.gestor ? _gestor : _entrenamiento;
  }

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
    final indiceActual = destinos.indexWhere((d) => d.ruta == location);
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
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: cambiaModo
          ? _BotonCambioModo(
              modo: modo,
              onPressed: () {
                final nuevo = ref.read(appModeProvider.notifier).alternar();
                // Lleva al primer destino del modo nuevo para no quedarse en
                // una pantalla que ya no está en la barra.
                context.go(_destinosPara(profile, nuevo).first.ruta);
              },
            )
          : null,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
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
    );
  }
}

/// Píldora flotante para saltar de un modo al otro.
class _BotonCambioModo extends StatelessWidget {
  const _BotonCambioModo({required this.modo, required this.onPressed});

  final AppMode modo;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Se despega de la barra inferior para no taparla.
      padding: const EdgeInsets.only(bottom: 4),
      child: FloatingActionButton.extended(
        onPressed: onPressed,
        elevation: 3,
        shape: const StadiumBorder(),
        backgroundColor: AppColors.ink,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.swap_vert, size: 20),
        label: Text(
          modo.etiquetaCambio,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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
