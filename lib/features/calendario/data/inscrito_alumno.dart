/// A student enrolled in a class, as shown in the teacher's roster
/// (`ClaseDetalleScreen`) together with whether attendance was already
/// validated for this specific class occurrence.
class InscritoAlumno {
  const InscritoAlumno({
    required this.alumnoId,
    required this.nombre,
    this.apellidos,
    this.fotoUrl,
    this.cinturon,
    required this.asistenciaValidada,
    this.sinCuota = false,
    this.sinClases = false,
  });

  factory InscritoAlumno.fromInscripcionJson(
    Map<String, dynamic> json, {
    required bool asistenciaValidada,
    bool sinCuota = false,
    bool sinClases = false,
  }) {
    final alumno = json['alumno'] as Map<String, dynamic>;
    return InscritoAlumno(
      alumnoId: json['alumno_id'] as String,
      nombre: alumno['nombre'] as String,
      apellidos: alumno['apellidos'] as String?,
      fotoUrl: alumno['foto_url'] as String?,
      cinturon: alumno['cinturon'] as String?,
      asistenciaValidada: asistenciaValidada,
      sinCuota: sinCuota,
      sinClases: sinClases,
    );
  }

  final String alumnoId;
  final String nombre;
  final String? apellidos;
  final String? fotoUrl;
  final String? cinturon;
  final bool asistenciaValidada;

  /// No tiene ninguna cuota activa y cobrada. Puede apuntarse igualmente
  /// —así lo quiere Cipri— pero sale marcado para poder cobrarle en mano.
  final bool sinCuota;

  /// Tiene cuota, pero esta reserva se pasa de las clases de su tarifa en
  /// ese ciclo: le reservó con saldo y después cambió algo (una pausa, una
  /// clase movida de fecha). Se mantiene y sale marcada para cobrarla en
  /// mano (decisión de Cipri, 09/10/2026).
  final bool sinClases;

  String get nombreCompleto =>
      [nombre, apellidos].whereType<String>().join(' ');
}
