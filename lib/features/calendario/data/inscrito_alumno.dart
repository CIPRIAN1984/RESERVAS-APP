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
  });

  factory InscritoAlumno.fromInscripcionJson(
    Map<String, dynamic> json, {
    required bool asistenciaValidada,
  }) {
    final alumno = json['alumno'] as Map<String, dynamic>;
    return InscritoAlumno(
      alumnoId: json['alumno_id'] as String,
      nombre: alumno['nombre'] as String,
      apellidos: alumno['apellidos'] as String?,
      fotoUrl: alumno['foto_url'] as String?,
      cinturon: alumno['cinturon'] as String?,
      asistenciaValidada: asistenciaValidada,
    );
  }

  final String alumnoId;
  final String nombre;
  final String? apellidos;
  final String? fotoUrl;
  final String? cinturon;
  final bool asistenciaValidada;

  String get nombreCompleto => [nombre, apellidos].whereType<String>().join(' ');
}
