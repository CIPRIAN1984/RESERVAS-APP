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
  });

  factory InscritoAlumno.fromInscripcionJson(
    Map<String, dynamic> json, {
    required bool asistenciaValidada,
    bool sinCuota = false,
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

  String get nombreCompleto =>
      [nombre, apellidos].whereType<String>().join(' ');
}
