import 'package:flutter/material.dart';

import '../../app/theme/color_tokens.dart';

/// Componentes de estructura del sistema de diseño I+.
/// Ver la skill `diseno-i-plus` antes de cambiar cualquiera de estos estilos.

/// Hueco que hay que dejar al final de todo lo que se desplaza.
///
/// Hueco que hay que dejar al final de una lista **cuando la pantalla tiene
/// botón flotante** («Crear clase», «Tarifa», «Publicar»…). Sin él, el botón
/// se queda encima del último elemento y no se puede pulsar ninguno de los
/// dos. Pasó con la última clase del día, que quedaba debajo de «Crear clase».
///
/// En las pantallas sin botón flotante no se pone: solo dejaría un vacío.
const double espacioBotonesFlotantes = 96;

/// Cabecera estándar de pantalla: título muy marcado y, opcionalmente, una
/// acción a la derecha y un antetítulo en monoespaciada.
class TituloPantalla extends StatelessWidget {
  const TituloPantalla(
    this.titulo, {
    this.antetitulo,
    this.accion,
    this.onVolver,
    super.key,
  });

  final String titulo;
  final String? antetitulo;
  final Widget? accion;

  /// Cuando se pasa, aparece una flecha de volver encima del título. Se usa
  /// en las pantallas a las que se llega desde otra, no desde la barra
  /// inferior (Equipo, Cobros, Ajustes de reservas…).
  final VoidCallback? onVolver;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, onVolver == null ? 20 : 8, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (onVolver != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: IconButton(
                onPressed: onVolver,
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Volver',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                alignment: Alignment.centerLeft,
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (antetitulo != null) ...[
                      Text(antetitulo!.toUpperCase(), style: t.labelSmall),
                      const SizedBox(height: 4),
                    ],
                    Text(titulo, style: t.displayLarge),
                  ],
                ),
              ),
              if (accion != null) ...[const SizedBox(width: 12), accion!],
            ],
          ),
        ],
      ),
    );
  }
}

/// Envuelve una pantalla con su cabecera.
///
/// Al pasar a barra inferior desaparecieron las barras de título de arriba,
/// así que el encabezado lo pone el router en un único sitio y cada pantalla
/// se ocupa solo de su contenido.
class PantallaConTitulo extends StatelessWidget {
  const PantallaConTitulo({
    required this.titulo,
    required this.child,
    this.onVolver,
    super.key,
  });

  final String titulo;
  final Widget child;
  final VoidCallback? onVolver;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TituloPantalla(titulo, onVolver: onVolver),
        Expanded(child: child),
      ],
    );
  }
}

/// Pestañas en forma de píldora: la activa en negro, las demás en gris.
class PestanasPildora extends StatelessWidget {
  const PestanasPildora({
    required this.valor,
    required this.etiquetas,
    required this.onCambio,
    super.key,
  });

  final int valor;
  final List<String> etiquetas;
  final ValueChanged<int> onCambio;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < etiquetas.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            _Pildora(
              texto: etiquetas[i],
              activa: i == valor,
              onTap: () => onCambio(i),
            ),
          ],
        ],
      ),
    );
  }
}

class _Pildora extends StatelessWidget {
  const _Pildora({
    required this.texto,
    required this.activa,
    required this.onTap,
  });

  final String texto;
  final bool activa;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: activa,
      child: InkWell(
        borderRadius: BorderRadius.circular(100),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
          decoration: BoxDecoration(
            color: activa ? AppColors.ink : AppColors.surface,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(
            texto,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: activa ? Colors.white : AppColors.subtle,
            ),
          ),
        ),
      ),
    );
  }
}

/// Pastilla de estado en tono pastel. El color aquí **significa** algo: verde
/// cobrado, rojo impagado, azul prueba, gris sin membresía.
class PastillaEstado extends StatelessWidget {
  const PastillaEstado(
    this.texto, {
    this.fondo = AppColors.neutralBg,
    this.tinta = AppColors.neutralFg,
    this.icono,
    super.key,
  });

  const PastillaEstado.exito(this.texto, {this.icono, super.key})
    : fondo = AppColors.successBg,
      tinta = AppColors.successFg;

  const PastillaEstado.error(this.texto, {this.icono, super.key})
    : fondo = AppColors.dangerBg,
      tinta = AppColors.dangerFg;

  const PastillaEstado.info(this.texto, {this.icono, super.key})
    : fondo = AppColors.infoBg,
      tinta = AppColors.infoFg;

  const PastillaEstado.aviso(this.texto, {this.icono, super.key})
    : fondo = AppColors.warningBg,
      tinta = AppColors.warningFg;

  final String texto;
  final Color fondo;
  final Color tinta;
  final IconData? icono;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono != null) ...[
            Icon(icono, size: 13, color: tinta),
            const SizedBox(width: 5),
          ],
          Text(
            texto.toUpperCase(),
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: tinta),
          ),
        ],
      ),
    );
  }
}

/// Punto del color del cinturón. El blanco lleva borde para verse sobre
/// fondo claro.
class PuntoCinturon extends StatelessWidget {
  const PuntoCinturon(this.cinturon, {this.tamano = 18, super.key});

  final String? cinturon;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    final necesitaBorde = AppColors.beltNeedsBorder(cinturon ?? 'blanco');
    return Semantics(
      label: 'Cinturón ${cinturon ?? 'blanco'}',
      child: Container(
        width: tamano,
        height: tamano,
        decoration: BoxDecoration(
          color: AppColors.belt(cinturon),
          shape: BoxShape.circle,
          border: necesitaBorde
              ? Border.all(color: AppColors.beltBorder)
              : null,
        ),
      ),
    );
  }
}

/// Acceso a otra pantalla presentado como tarjeta: icono, título, una línea
/// que explica qué hay dentro y galón a la derecha.
///
/// Vive aquí y no en una pantalla concreta porque lo usan tanto Herramientas
/// (modo Gestor) como Perfil (modo Entrenamiento), y deben verse idénticos.
class TarjetaAcceso extends StatelessWidget {
  const TarjetaAcceso({
    required this.icono,
    required this.titulo,
    required this.descripcion,
    required this.destino,
    super.key,
  });

  final IconData icono;
  final String titulo;
  final String descripcion;
  final Widget destino;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(title: Text(titulo)),
              body: SafeArea(child: destino),
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(icono, size: 26),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      descripcion,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.subtle),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.disabled,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
